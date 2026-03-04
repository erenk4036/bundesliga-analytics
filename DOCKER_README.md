# 🐳 Local Development with Docker

## What is being simulated?

| AWS Service     | Local Simulation         | Port  |
|-----------------|--------------------------|-------|
| DynamoDB        | `amazon/dynamodb-local`  | 8000  |
| S3              | `localstack/localstack`  | 4566  |
| Lambda Runtime  | AWS Lambda Base Image    | —     |

---

## Requirements

- [Docker Desktop](https://www.docker.com/products/docker-desktop/)
- [AWS CLI](https://aws.amazon.com/cli/) 

---

## Starting local environment

```bash
# 1. Repository clone
git clone https://github.com/erenk4036/bundesliga-analytics.git
cd bundesliga-analytics

# 2. Start all services (DynamoDB Local + LocalStack S3)
docker compose up -d

# 3. Wait till all services are setup
docker compose ps
```

---

## check services

```bash
# Show DynamoDB Tables
aws dynamodb list-tables \
  --endpoint-url http://localhost:8000 \
  --region eu-central-1 \
  --no-sign-request

# Show S3 Buckets
aws s3 ls \
  --endpoint-url http://localhost:4566 \
  --no-sign-request

# Check logs
docker compose logs -f
```

---

## Local vs. AWS Stack

```
Local (Docker)                    AWS (Production)
──────────────────────────────────────────────────
DynamoDB Local ──────────────► DynamoDB
LocalStack S3  ──────────────► S3
Lambda Container ────────────► Lambda in VPC
docker compose run ──────────► EventBridge (08:00 UTC)
```

---

## Environment variables


```bash
ENVIRONMENT=local        # Uses local endpoints
ENVIRONMENT=dev          # Uses AWS dev environment
ENVIRONMENT=prod         # Uses AWS prod environment
```

---

## Clean up

```bash
# Container stoppen
docker compose down

# Container + Volumes löschen (sauberer Neustart)
docker compose down -v
```
