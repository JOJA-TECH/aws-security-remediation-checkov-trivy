locals {
  name = "${var.project}-${var.environment}"

  common_tags = {
    Equipo      = var.team
    Proyecto    = var.project
    Ambiente    = var.environment
    Responsable = var.owner
    ManagedBy   = "terraform"
    Version     = "remediated"
  }
}
