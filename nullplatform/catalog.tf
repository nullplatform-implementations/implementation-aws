# Catalog entry that records which module releases went into each build of a
# mobile orchestrator app (mobile-sample-app). The modules are applications of
# their own in the mobile namespace, without scopes: their CI publishes an AAR
# and a release per version. The orchestrator CI resolves the pinned versions to
# those releases and writes them here, so a build can be traced back to the
# exact module builds it shipped.
resource "nullplatform_metadata_specification" "mobile_modules" {
  name        = "Mobile modules"
  description = "Module releases bundled into a mobile app build"
  nrn         = "organization=1698562351:account=1372325109:namespace=366172610"
  entity      = "build"
  metadata    = "mobile_modules"

  schema = jsonencode({
    type = "object"
    properties = {
      modules = {
        type = "array"
        items = {
          type = "object"
          properties = {
            name           = { type = "string", description = "Module artifact id (design-system, auth-sdk, payments-sdk)" }
            version        = { type = "string", description = "Module version pinned by the orchestrator" }
            application_id = { type = "integer", description = "nullplatform application of the module" }
            release_id     = { type = "integer", description = "Release of the module that matches the version" }
            build_id       = { type = "integer", description = "Build that produced that module release" }
          }
          required             = ["name", "version"]
          additionalProperties = false
        }
      }
    }
    required             = ["modules"]
    additionalProperties = false
  })
}
