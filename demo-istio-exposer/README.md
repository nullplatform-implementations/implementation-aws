# demo-istio-exposer

Stack aislado para la demo de ruteo L7 con Istio + Endpoint Exposer.

Cluster propio y no reuso del compartido: el `AuthorizationPolicy` que genera el Endpoint Exposer
selecciona el workload del gateway completo (`gateway.networking.k8s.io/gateway-name`), y en Istio una
policy `ALLOW` sobre un workload deniega todo lo que no matchee sus reglas. Sobre el gateway del
cluster compartido eso le daria 403 a las HTTPRoutes de los demas scopes de la cuenta.

## Orden de aplicacion

Cada layer lee el state del anterior via `terraform_remote_state`, asi que el orden no es opcional:

1. `infrastructure/`        - VPC, EKS, DNS + delegacion NS, Istio, gateways, agente, Cognito, ECR
2. `nullplatform/`          - namespace, scope spec dedicado, spec del Endpoint Exposer, application
3. `nullplatform-bindings/` - canales de notificacion (con el override del exposer) y asset repository

## Comandos

Desde cada directorio:

    export AWS_PROFILE=implementations
    tofu init
    tofu plan  -var-file="../../common.tfvars" -var-file="terraform.tfvars" -out=tfplan
    tofu apply tfplan

`common.tfvars` vive en la raiz del repo y esta gitignoreado. Nunca correr `apply` sin revisar el
`plan`: cualquier `destroy` en este stack es una senal de error, no un cambio esperado.

## Nombres reservados

El cluster compartido de la cuenta ya usa `k8s-np-aws-services-public` / `-int` como nombres de load
balancer y `10.0.0.0/16` como CIDR. Este stack usa `k8s-np-uala-demo-*` y `10.40.0.0/16` para no chocar.
