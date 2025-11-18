resource "aws_instance" "main" {
  ami           = local.ami_id
  #component_name = local.component_name   # u will get from 90-componet test module as value like "catalogue"
  instance_type = "t3.micro"
  subnet_id = local.private_subnet_ids # we are creating mongodb in database subnet -> reffering local.tf
  vpc_security_group_ids = [data.aws_ssm_parameter.sg_id.value]  #reffering data.tf
  tags = {
    Name = "${var.component_name}"
    Environment = "dev"
    ec2 =  "${var.component_name}"


  }
}


resource "terraform_data" "main1" {
  triggers_replace = [
    aws_instance.main.id
  ]
  
  connection {
    type     = "ssh"
    user     = "ec2-user"
    password = "DevOps321"
    host     = aws_instance.main.private_ip
  }

  # terraform copies this file to catalogue server

  provisioner "file" {
    source = "bootstrap.sh"
    destination = "/tmp/bootstrap.sh"
  }
  
  #giving execute permission to tht bootstrap file
  provisioner "remote-exec" {
    inline = [
        "chmod +x /tmp/bootstrap.sh",
        #"sudo sh /tmp/bootstrap.sh",
        "sudo sh /tmp/bootstrap.sh ${var.component_name} ${var.environment}"
    ]
  }
}


resource "aws_ec2_instance_state" "instance-state" {
  instance_id = aws_instance.main.id
  state = "stopped"
  depends_on = [terraform_data.main1]
}

#This Terraform block is creating an "NEW AMI" (Amazon Machine Image) from your running EC2 instance.(catalogue_ec2) which will have os level info and services running in it
resource "aws_ami_from_instance" "ami-id-new" {
  name               = "${local.common_name_suffix}-${var.component_name}-ami"
  source_instance_id = aws_instance.main.id # we are creating new ami from base one
  depends_on = [aws_ec2_instance_state.instance-state]
  tags = {
    Name = "${var.component_name}"
    Environment = "dev"
    ec2 = "${var.component_name}"


  }
}

# launh templates helps Auto scaling group to create instances .
resource "aws_launch_template" "instances_launch_template" {
  name = "${local.common_name_suffix}-${var.component_name}"
  image_id = aws_ami_from_instance.ami-id-new.id   # we giving here new ami id

  instance_initiated_shutdown_behavior = "terminate"
  instance_type = "t3.micro"

  vpc_security_group_ids = [data.aws_ssm_parameter.sg_id.value] # it takes list, but we gave one [<sg_id>]

  # when we run terraform apply again, a new version will be created with new AMI ID
  #when there is configuration change and hit terraform apply then ami will change at tht time we need to maintain versions
  #When you change AMI in Terraform:
  #Terraform creates launch template version 2
  #And automatically makes version 2 the default.   VERY IMPORTYANT BELOW LINE "IN ORDER NOT TO MISS NEW ANSIBLE CONIG"
  
  update_default_version = true  #And automatically makes version 2 as the default, because ASG need to use latesest chanhges to create ec2. VERY IMPORTANT

  # tags attached to the instance
  tag_specifications {
    resource_type = "instance"

    tags = {
    Name = "catalogue-"
   
  }
  }
  # tags attached to the volume created by instance
  tag_specifications {
    resource_type = "volume"

    tags = {
    Name = "catalogue-"
   
  }
  }

  # tags attached to the launch template
  tags = {
    Name = "catalogue-"
   
  }

}

resource "aws_lb_target_group" "respective_target_group" {
  name     = "${local.common_name_suffix}-${var.component_name}"
  port     = local.tg_port # accept 
  protocol = "HTTP"
  vpc_id   = data.aws_ssm_parameter.vpc_id.value

    health_check {
    healthy_threshold = 2
    interval = 10
    matcher = "200-299"
    path = local.health_check_path
    port = local.tg_port
    protocol = "HTTP"
    timeout = 2
    unhealthy_threshold = 2
  }
}



resource "aws_autoscaling_group" "ASG" {
  name                      = "${local.common_name_suffix}-${var.component_name}-ASG"
  max_size                  = 10
  min_size                  = 1
  health_check_grace_period = 100
  health_check_type         = "ELB"
  desired_capacity          = 1
  force_delete              = false
  #giving here launch template details to ASG
  launch_template {
    id      = aws_launch_template.instances_launch_template.id
    version = aws_launch_template.instances_launch_template.latest_version
  }
  #giving here details about which zone and subnet these ec2 need to create

  #vpc_zone_identifier = "local.private_subnet_ids always expects a LIST, not a string."
  vpc_zone_identifier       = local.private_subnet_idss

  #After creating send to Target group
  #👉 “Attach this Auto Scaling Group to this Target Group.”
  #arn -> amazon resource name
  target_group_arns = [aws_lb_target_group.respective_target_group.arn] #ASG need to send ec2's to this target group where it have list of ec2's



  # we are going to refresh launch template whenever there is change in new AMI configuration. through rolling update strategy
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50 # atleast 50% of the instances should be up and running
    }
    triggers = ["launch_template"]
  }
  
  

  timeouts {
    delete = "15m"
  }

}


resource "aws_autoscaling_policy" "ASG-POLICY" {
  autoscaling_group_name = aws_autoscaling_group.ASG.name
  name                   = "${local.common_name_suffix}-${var.component_name}"
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 75.0
  }
}



resource "aws_lb_listener_rule" "respective_listener" {
  listener_arn = local.listener_arn 
  priority     = var.rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.respective_target_group.arn
  }

  condition {
    host_header {
      values = [local.host_context]
    }
  }
} #${var.comonent_name}.backend-alb-${var.environment}.${var.domain_name}


