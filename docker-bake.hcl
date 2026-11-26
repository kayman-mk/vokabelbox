target "web" {
  cache-from = ["type=gha,scope=vokabelhain-web"]
  cache-to   = ["type=gha,scope=vokabelhain-web,mode=max"]
}

target "api" {
  cache-from = ["type=gha,scope=vokabelhain-api"]
  cache-to   = ["type=gha,scope=vokabelhain-api,mode=max"]
}
