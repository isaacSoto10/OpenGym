import { defineRailway, preserve, project, service, volume } from "railway/iac";

export default defineRailway(() => {
  const data = volume("opengym-data", {
    region: "us-east4-eqdc4a",
    sizeMB: 1024,
  });

  const app = service("opengym", {
    build: {
      builder: "DOCKERFILE",
      dockerfilePath: "deploy/railway/Dockerfile",
    },
    healthcheck: "/api/health",
    healthcheckTimeout: 30,
    replicas: {
      "us-east4-eqdc4a": 1,
    },
    deploy: {
      restartPolicyType: "ON_FAILURE",
      restartPolicyMaxRetries: 10,
      drainingSeconds: 15,
    },
    volumeMounts: {
      "/data": data,
    },
    env: {
      NODE_ENV: "production",
      DATA_DIR: "/data",
      API_PORT: "3000",
      RP_NAME: "openGym",

      // Set these in Railway after choosing the permanent public domain. preserve() keeps the
      // operator-owned values out of source control and prevents later IaC applies removing them.
      RP_ID: preserve(),
      ORIGIN: preserve(),
      ADMIN_UIDS: preserve(),
      INVITE_ONLY: preserve(),
      ALLOW_GUEST: preserve(),
      SESSION_DAYS: preserve(),
      AUDIT_LOG: preserve(),
      AUDIT_MAX: preserve(),
      AUDIT_DAYS: preserve(),
      AUDIT_IP: preserve(),
      VAPID_SUBJECT: preserve(),
    },
  });

  return project("opengym", {
    resources: [app, data],
  });
});
