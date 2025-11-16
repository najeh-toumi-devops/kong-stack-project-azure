# Kong Stack Project — Azure deployment

This repository contains scripts and sources to deploy a Kong API Gateway + Flask API stack on Azure VMs, including monitoring and logging (Prometheus/Grafana, ELK).

## Tech Stack

| API Gateway | Web Server | Backend | Cache | Database | Logging | Metrics | Dashboards | Cloud |
|---|---|---|---|---|---|---|---|---|
| ![Kong](https://raw.githubusercontent.com/Kong/docs.konghq.com/main/app/_assets/images/logo-2.png?size=50) | ![Nginx](https://raw.githubusercontent.com/nginx/nginx.org/master/xml/en/docs/logo_nginx.png?size=50) | ![Flask](https://flask.palletsprojects.com/en/3.0.x/_images/flask-logo.png?size=50) | ![Redis](https://raw.githubusercontent.com/redis/redis/unstable/docs/logo.png?size=50) | ![MongoDB](https://www.mongodb.com/assets/media/mongodb-logo.png?size=50) | ![Elasticsearch](https://www.elastic.co/favicon.ico) ![Kibana](https://www.elastic.co/favicon.ico) | ![Prometheus](https://raw.githubusercontent.com/prometheus/prometheus.io/main/content/assets/prometheus_logo_grey.svg?size=50) | ![Grafana](https://raw.githubusercontent.com/grafana/grafana/main/public/img/grafana_icon.svg?size=50) | ![Azure](https://raw.githubusercontent.com/Azure/azure-rest-api-specs/master/docs/logo-logo.png?size=50) |

## Architecture

### Kong Stack Architecture

![Architecture diagram](docs/images/archi-kong.png)

### Azure Global Architecture

![Azure Global Architecture](docs/images/Azure_Global_Architecture_Interactive.png)

## Architecture Overview & Data Flows

### System Components

1. **User Layer**
   - External clients/users making requests

2. **VM-KONG (API Gateway)** ![Kong](https://raw.githubusercontent.com/Kong/docs.konghq.com/main/app/_assets/images/logo-2.png?size=30)
   - **Port 8000**: Main API endpoint (user-facing)
   - Components:
     - ![Kong](https://raw.githubusercontent.com/Kong/docs.konghq.com/main/app/_assets/images/logo-2.png?size=30) Kong Gateway (manages routing, authentication, rate limiting)
     - ![Nginx](https://raw.githubusercontent.com/nginx/nginx.org/master/xml/en/docs/logo_nginx.png?size=30) Nginx (reverse proxy, load balancing)
     - ![Flask](https://flask.palletsprojects.com/en/3.0.x/_images/flask-logo.png?size=30) Flask API (backend application)
     - ![Redis](https://raw.githubusercontent.com/redis/redis/unstable/docs/logo.png?size=30) Redis (caching, sessions)
     - ![MongoDB](https://www.mongodb.com/assets/media/mongodb-logo.png?size=30) MongoDB (persistent data storage)

3. **VM-LOGS (Logging & Aggregation)** ![Elasticsearch](https://www.elastic.co/favicon.ico)
   - **Port 8000**: Data ingestion from Kong
   - **Port 9200**: Kibana UI
   - Components:
     - ![Elasticsearch](https://www.elastic.co/favicon.ico) Elasticsearch (log indexing and search)
     - ![Kibana](https://www.elastic.co/favicon.ico) Kibana (log visualization dashboard)
     - ![Gfren](https://raw.githubusercontent.com/gfren/gfren/main/docs/logo.png?size=30) Gfren (log forwarder)
     - ![Azure](https://raw.githubusercontent.com/Azure/azure-rest-api-specs/master/docs/logo-logo.png?size=30) Azure (cloud integration for log storage)

4. **VM-MONITORING (Metrics & Alerting)** ![Prometheus](https://raw.githubusercontent.com/prometheus/prometheus.io/main/content/assets/prometheus_logo_grey.svg?size=30)
   - **Port 9200**: Prometheus metrics endpoint
   - **Port 3000**: Grafana dashboard UI
   - Components:
     - ![Prometheus](https://raw.githubusercontent.com/prometheus/prometheus.io/main/content/assets/prometheus_logo_grey.svg?size=30) Prometheus (metrics collection and storage)
     - ![Grafana](https://raw.githubusercontent.com/grafana/grafana/main/public/img/grafana_icon.svg?size=30) Grafana (metrics visualization)
     - ![Alertmanager](https://raw.githubusercontent.com/prometheus/alertmanager/main/doc/overview.md?size=30) Alertmanager (alert routing and grouping)
     - ![Exporters](https://raw.githubusercontent.com/prometheus/node_exporter/main/README.md?size=30) Exporters (MongoDB exporter, Redis exporter)

### Request Flow (Step-by-Step)

1. **Incoming User Request**
   - User sends HTTP request to Kong Gateway (Port 8000)
   - Kong validates authentication and applies rate limiting

2. **API Processing**
   - Kong routes request to Flask API
   - Flask checks Redis cache for quick response
   - If cache miss, Flask queries MongoDB for data

3. **Response Path**
   - Flask returns response to Kong
   - Kong sends HTTP response back to user

4. **Logging**
   - Kong logs request/response metadata
   - Logs shipped to VM-LOGS via Gfren
   - Elasticsearch indexes logs for searchability
   - Kibana displays logs in real-time dashboard

5. **Monitoring**
   - Prometheus scrapes metrics from all services:
     - Kong metrics (requests, latency, errors)
     - MongoDB metrics (via mongodb_exporter)
     - Redis metrics (via redis_exporter)
   - Grafana visualizes metrics with dashboards
   - Alertmanager triggers alerts on anomalies

### Key Ports & Services

| VM | Port | Service | Purpose |
|---|---|---|---|
| VM-KONG | 8000 | Kong API Gateway | API requests |
| VM-KONG | 6379 | Redis | Caching |
| VM-KONG | 5044 | MongoDB | Data persistence |
| VM-LOGS | 8000 | Elasticsearch Ingest | Log aggregation |
| VM-LOGS | 9200 | Kibana | Log visualization |
| VM-MONITORING | 9200 | Prometheus | Metrics collection |
| VM-MONITORING | 3000 | Grafana | Metrics dashboard |

## Deployment

To deploy this stack on Azure, use the scripts in the `infrastructure/` directory. Each VM requires specific setup scripts for dependencies and services.

## Quick Start

```bash
# Deploy API VM
cd infrastructure/api-vm
./deploy-api.sh

# Or deploy source directly
cd src/stock-api
./start.sh
```
