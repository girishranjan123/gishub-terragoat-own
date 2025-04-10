resource "google_sql_database_instance" "master" {
  provider            = google-beta
  project             = var.project_id
  name                = local.master_instance_name
  database_version    = can(regex("\\d", substr(var.database_version, 0, 1))) ? format("POSTGRES_%s", var.database_version) : replace(var.database_version, substr(var.database_version, 0, 8), "POSTGRES")
  region              = var.region
  encryption_key_name = var.encryption_key_name
  deletion_protection = var.deletion_protection
  root_password       = data.google_secret_manager_secret_version.root_password_version.secret_data

  settings {
    tier                        = var.tier
    edition                     = var.edition
    activation_policy           = var.activation_policy
    availability_type         = var.availability_type
    deletion_protection_enabled = var.deletion_protection_enabled
    connector_enforcement       = local.connector_enforcement

    dynamic "backup_configuration" {
      for_each = [var.backup_configuration]
      content {
        enabled                       = local.backups_enabled
        start_time                    = lookup(backup_configuration.value, "start_time", null)
        location                      = lookup(backup_configuration.value, "location", null)
        point_in_time_recovery_enabled = local.point_in_time_recovery_enabled
        transaction_log_retention_days = lookup(backup_configuration.value, "transaction_log_retention_days", null)

        dynamic "backup_retention_settings" {
          for_each = local.retained_backups != null || local.retention_unit != null ? [var.backup_configuration] : []
          content {
            retained_backups = local.retained_backups
            retention_unit   = local.retention_unit
          }
        }
      }
    }

    dynamic "data_cache_config" {
      for_each = var.edition == "ENTERPRISE_PLUS" && var.data_cache_enabled ? ["cache_enabled"] : []
      content {
        data_cache_enabled = var.data_cache_config
      }
    }

    dynamic "deny_maintenance_period" {
      for_each = var.deny_maintenance_period
      content {
        end_date   = lookup(deny_maintenance_period.value, "end_date", null)
        start_date = lookup(deny_maintenance_period.value, "start_date", null)
        time       = lookup(deny_maintenance_period.value, "time", null)
      }
    }

    dynamic "database_flags" {
      for_each = var.database_flags
      content {
        name  = database_flags.value["name"]
        value = database_flags.value["value"]
      }
    }

    ip_configuration {
      dynamic "authorized_networks" {
        for_each = var.authorized_networks
        content {
          name      = authorized_networks.value["name"]
          value     = authorized_networks.value["value"]
          expiration = lookup(authorized_networks.value, "expiration", null)
        }
      }
      ipv4_enabled = var.ipv4_enabled
      private_network = var.private_network
      require_ssl = false
    }

    location_preference {
      zone = var.zone
    }

    maintenance_window {
      day          = var.maintenance_window_day
      hour         = var.maintenance_window_hour
      update_track = var.maintenance_window_update_track
    }

    dynamic "insights_config" {
      for_each = var.edition == "ENTERPRISE_PLUS" ? ["insights_config"] : []
      content {
        query_insights_enabled  = var.query_insights_enabled
        record_application_tags = var.record_application_tags
        record_client_address   = var.record_client_address
        query_plans_per_minute  = var.query_plans_per_minute
        query_string_length     = var.query_string_length
      }
    }
  }
}
