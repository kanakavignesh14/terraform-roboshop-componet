locals{
    comonent_name = var.comonent_name
    ami_id = data.aws_ami.joindevops.id
    private_subnet_ids = split(",",data.aws_ssm_parameter.private_subnet_ids.value)[0]    #["10.0.1.0/24"]
    vpc_id = data.aws_ssm_parameter.vpc_id.value
    private_subnet_idss = split("," , data.aws_ssm_parameter.private_subnet_ids.value)  # here we will get from ssmparameter list ["10.0.1.0/24","10.0.2.0/24"]
                      #  ["10.0.1.0/24","10.0.2.0/24"]
    backend_alb_listener-arn = data.aws_ssm_parameter.backend_alb_listener-arn.value
    frontend_alb_listener-arn = data.aws_ssm_parameter.frontend_alb_listener-arn.value
    listener_arn = ${var.comonent} == "frontend" ? local.frontend_alb_listener : local.backend_alb_listener

    tg_port = ${var.comonent_name} == "frontend" ? 80 : 8080  
    health_check_path =   ${var.comonent_name} == "frontend" ? "/" : "/health"     
    host_context = ${var.comonent} == "frontend" ? "${var.project_name}-${var.environment}.${domain_name}" : ${var.comonent_name}.backend-alb-${var.environment}.${var.domain_name}        
}