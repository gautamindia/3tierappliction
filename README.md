# 3-Tier Web Application: Terraform + GitHub Actions

A minimal but complete 3-tier deployment on AWS:

```
Internet
   │  HTTP :80
   ▼
┌─────────────────┐   peering    ┌─────────────────┐   peering    ┌─────────────────┐
│  Frontend VPC    │◄────────────►│  Backend VPC     │◄────────────►│  Database VPC    │
│  10.0.0.0/16     │  :5000 only  │  10.1.0.0/16     │  :5432 only  │  10.2.0.0/16     │
│  EC2 (Flaska UI)  │              │  EC2 (Flask API) │              │  RDS (Postgres)  │
└─────────────────┘              └─────────────────┘              └─────────────────┘
                                                                     (private subnets,
                                                                      no route to FE)
```

## Why the frontend can't reach the database

Two things enforce this, independently:

1. **No routing path.** VPC peering connections are non-transitive in AWS. There is a
   peering connection frontend↔backend and one backend↔database, but **none** between
   frontend and database. A packet from the frontend VPC has no route into the database
   VPC's CIDR at all — not "blocked", genuinely unroutable.
2. **Security groups**, as defense in depth:
   - `frontend-sg`: ingress 80 from the internet + SSH from an admin CIDR; egress only to
     the backend VPC on port 5000 (plus 80/443 out for OS package updates).
   - `backend-sg`: ingress on 5000 only from the frontend VPC CIDR; egress only to the
     database VPC on 5432.
   - `database-sg`: ingress on 5432 only from the backend VPC CIDR. No public accessibility.

## Repo layout

```
terraform/
  modules/
    vpc/              # one VPC + public and/or private subnets + route tables
    peering/           # a peering connection + the routes on both sides
    security_group/    # generic SG with dynamic ingress/egress rule lists
    ec2/                # EC2 instance + IAM role/profile for SSM access
    rds/                # RDS instance + DB subnet group
  environments/
    dev/                # root module: wires the modules above together
      templates/        # user_data bootstrap scripts (first boot only)
app/
  frontend/             # Flask UI - talks to the backend over HTTP, never to RDS
  backend/              # Flask API - business logic + the only tier that talks to RDS
.github/
  workflows/
    terraform-deploy-template.yml  # reusable: plan/apply Terraform
    app-deploy-template.yml        # reusable: deploy one tier via SSM Run Command
    infra-deploy.yml               # caller: plans on PR, applies on push to main
    app-deploy.yml                 # caller: deploys frontend+backend on push to main
```

## The application

- **Backend** (`app/backend/app.py`): a Flask API backed by Postgres. Business logic
  example: `apply_bulk_discount()` computes a tiered bulk-discount total price
  (0% under 5 units, 10% for 5-9, 15% for 10+) — this is computed server-side, not in
  the browser. Endpoints: `GET/POST /api/items`, `GET /api/health`.
- **Frontend** (`app/frontend/app.py`): a Flask UI. On page load it calls
  `GET {BACKEND_URL}/api/items` and renders the results (including the backend-computed
  total price) in a table; a form `POST`s new items to the backend.
- Frontend and backend are otherwise stateless — the only durable data lives in RDS.

## Deploying infrastructure

1. `cd terraform/environments/dev`
2. `cp terraform.tfvars.example terraform.tfvars` and fill in `admin_cidr`, `repo_url`.
3. Provide secrets as environment variables (never commit them):
   ```
   export TF_VAR_db_password="..."
   export TF_VAR_flask_secret_key="..."
   ```
4. `terraform init && terraform plan && terraform apply`
5. `terraform output frontend_public_ip` → open it in a browser.

On first boot, each EC2 instance's `user_data` bootstraps Python, clones the app repo,
and starts the relevant systemd service (`frontend.service` / `backend.service`) once.
**Ongoing** deploys after that go through the app-deploy pipeline (below), not user_data.

## CI/CD

Two independent, reusable pipelines, matching the two requirements:

### 1. Infra pipeline — `terraform-deploy-template.yml`

A `workflow_call` reusable workflow: `terraform init/validate/plan`, and `apply` only
when `apply: true` is passed in. `infra-deploy.yml` calls it: plan-only on pull requests
that touch `terraform/**`, apply on push to `main`. Authenticates to AWS via OIDC
(`aws-actions/configure-aws-credentials`) — no long-lived AWS keys stored in GitHub.

### 2. App pipeline — `app-deploy-template.yml`

A separate `workflow_call` reusable workflow that deploys **one tier** at a time onto
already-provisioned infrastructure. It:
1. Looks up the running EC2 instance by its `Project`/`Tier` tags (so it needs no
   Terraform state or outputs — fully decoupled from the infra pipeline).
2. Runs `app/<tier>/deploy.sh` on that instance via **SSM Run Command** — no SSH keys,
   no open port 22 needed for deploys (22 is still open to `admin_cidr` for break-glass).
3. `deploy.sh` does a fresh shallow clone of the app repo, rebuilds the Python venv,
   and restarts the tier's systemd service.

`app-deploy.yml` calls it twice (backend, then frontend) on push to `main` touching
`app/**`, or manually via `workflow_dispatch` for a single tier.

### Required GitHub configuration

- Repo variable `APP_REPO_URL` — the git URL of this repo.
- Secrets: `AWS_ROLE_ARN` (an IAM role trusted for GitHub OIDC, scoped to the actions
  each pipeline needs — EC2/VPC/RDS/IAM for infra, `ssm:SendCommand`/`ec2:DescribeInstances`
  for app deploy), `DB_PASSWORD`, `FLASK_SECRET_KEY`.
- A GitHub **Environment** named `dev` (add required reviewers here for a manual
  approval gate before `apply`, if wanted).

## Known simplifications (call these out if this goes to production)

- Single EC2 instance per tier, no Auto Scaling Group / Load Balancer — fine for a demo,
  not for HA. Swap `modules/ec2` usage for an ASG + ALB module for production.
- No NAT Gateway: frontend/backend sit in *public* subnets (with locked-down SGs) so
  they can reach the internet for package installs without the cost of a NAT Gateway.
  For a stricter posture, move them to private subnets + NAT Gateway.
- `deploy.sh` assumes the app repo is public (it `curl`s the raw script, then
  `git clone`s over HTTPS). For a private repo, mount a deploy token/PAT via SSM
  Parameter Store and reference it in `deploy.sh`, or use a self-hosted runner with
  repo access instead of SSM `curl`.
- RDS is single-AZ with `skip_final_snapshot = true` — fine for dev, flip both for prod.
- `terraform.tfstate` is local by default; the `backend "s3"` block in
  `providers.tf` is stubbed out and commented — enable it (with a DynamoDB lock table)
  before using this with a team or in CI for real.
# 3tierappliction
