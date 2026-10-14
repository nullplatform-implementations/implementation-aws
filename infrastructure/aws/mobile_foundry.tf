# Technical user the voltmx-foundry-app scope authenticates to Foundry with.
# The scope only accepts secrets under voltmx/<namespace slug>/, so each
# namespace gets its own Foundry user. These values are for the POC, where
# MFCLI_CMD points at the mfcli mock: they are not real credentials.
resource "aws_secretsmanager_secret" "voltmx_mobile_foundry_user" {
  name                    = "voltmx/mobile/foundry-user"
  description             = "Foundry technical user of the mobile namespace (mock values for the POC)"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "voltmx_mobile_foundry_user" {
  secret_id = aws_secretsmanager_secret.voltmx_mobile_foundry_user.id
  secret_string = jsonencode({
    username = "mock-foundry-user"
    password = "mock-foundry-password"
  })
}
