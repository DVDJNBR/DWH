resource "azurerm_portal_dashboard" "main" {
  name                = var.dashboard_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order  = 0
        parts  = {
          "0" = {
            position = {
              x  = 0
              y  = 0
              rowSpan = 4
              colSpan = 6
            }
            metadata = {
              inputs = [
                {
                  name     = "Component"
                  value    = var.stream_analytics_job_id
                  isOptional = false
                }
              ]
              type     = "Extension/HubsExtension/PartType/BrowseResourceGroupV2"
              settings = {
                content = {
                  Component = {
                    Name    = "Component",
                    Value   = var.stream_analytics_job_id
                  }
                }
              }
            }
          },
          "1" = {
            position = {
              x  = 6
              y  = 0
              rowSpan = 4
              colSpan = 6
            }
            metadata = {
              inputs = [
                {
                  name  = "id"
                  value = var.stream_analytics_job_id
                }
              ]
              type     = "Extension/Microsoft_Azure_StreamAnalytics/PartType/JobSummaryPart"
            }
          },
          "2" = {
            position = {
              x  = 0
              y  = 4
              rowSpan = 4
              colSpan = 12
            }
            metadata = {
              inputs = [
                {
                  name  = "resourceId"
                  value = var.stream_analytics_job_id
                }
              ]
              type     = "Extension/Microsoft_Azure_StreamAnalytics/PartType/JobMonitoringPart"
            }
          }
        }
      }
    }
    metadata = {
      model = {
        timeRange = {
          value = {
            relative = {
              duration = 24
              timeUnit = 1
            }
          }
          type = "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
        }
      }
    }
  })
}
