# Product Help Agent

A shopping assistant for Summit Outdoor, a fictional outdoor gear store. Shoppers ask it things like
"Is the Trailblazer jacket in stock in size M?" or "What's your return policy?", and it answers from the
store's catalog through MCP tools.

The store's Products API already runs somewhere, with a known URL and API key. You register it once as a
WSO2 Cloud Resource. The MCP server declares that Resource, so the platform gives it the API's URL and key
on deploy, and nobody sets a secret on a component.

```
Try It ──▶ Product Help Agent ──▶ MCP gateway ──▶ Products MCP server ──▶ Products API
           (Agent Manager)       (API Platform)   (Integrator)            (hosted anywhere)
                                                        ▲
                                     URL and key from the products-catalog-api Resource
```

| Component | Runs on | Path | Language |
|---|---|---|---|
| Products API | Anywhere with a public URL | `products-api/` | Ballerina 2201.13.1 |
| Products MCP server | Integrator, `mcp-server` | `products-mcp/` | Ballerina 2201.13.1 |
| Product Help Agent | Agent Manager, platform-hosted chat agent | `agent/` | Python 3.11 |

The catalog, stock and policies are fictional mock data, and everything is read-only.

## Deploy on WSO2 Cloud

### 1. Register the Products API as a Resource

Under **Resources**, register a custom Resource named `products-catalog-api` with two keys, and set their
values for each environment:

| Key | Secret | Value |
|---|---|---|
| `PRODUCTS_API_URL` | No | The Products API's base URL, so that `<URL>/products` is the search |
| `PRODUCTS_API_KEY` | Yes | The key the Products API, or its gateway, expects in `X-API-Key` |

Then attach the Resource to the project you deploy the MCP server to.

#### The hosted Products API

To try the sample without hosting the API yourself, use the copy WSO2 runs on the WSO2 Cloud development
environment:

| Key | Value |
|---|---|
| `PRODUCTS_API_URL` | `https://qwt3nn5sk6-gw-p1.gateway.dp.dev.cloud.wso2.com/products-api-api-v1-2c76c944/v1.0` |
| `PRODUCTS_API_KEY` | Ask the WSO2 Cloud sample team for the key |

The URL works only while that deployment exists, and it may change when the development environment is
reset. If it stops working, host `products-api/` yourself and use your own URL and key.

### 2. Deploy the MCP server

In the Integration Platform, create an integration from this repository: type `mcp-server`, path
`products-mcp`, WSO2 Integrator runtime. Don't set any environment variables on it.

[`products-mcp/workload.yaml`](products-mcp/workload.yaml) declares the Resource:

```yaml
dependencies:
  resources:
    - ref: default-products-catalog-api
      envBindings:
        PRODUCTS_API_URL: PRODUCTS_API_URL
        PRODUCTS_API_KEY: PRODUCTS_API_KEY
```

The `ref` is `<project>-<resource>`. Change `default` if you deploy to another project. The deploy waits
until the Resource is ready in that environment.

Then make the integration's endpoint public, so it's published on the MCP gateway. The MCP URL is that
gateway URL plus `/mcp`.

### 3. Deploy the agent

In Agent Manager, create a platform-hosted Python agent from this repository: app path `/agent`,
Python 3.11, default chat interface. Then:

1. Bind an Anthropic LLM provider, with the env var names `LLM_PROVIDER_URL` and `LLM_PROVIDER_KEY`.
2. Set `PRODUCTS_MCP_URL` to the MCP URL from step 2, and `MCP_API_KEY` to the MCP gateway's API key,
   as a secret.
3. Deploy, then open **Try It**.

## Products API

A read-only REST API over mock data, with no auth code. Host it anywhere behind a gateway that checks an
API key. Base path `/api/v1`, port `8080`.

| Method and path | Returns |
|---|---|
| `GET /products?query=&category=` | Matching products, best rated first |
| `GET /products/{sku}` | One product |
| `GET /products/{sku}/stock` | Units per size |
| `GET /policies`, `GET /policies/{topic}` | Store policies: returns, shipping, warranty, price-match |
| `GET /health` | `{"status":"ok"}` |

## Products MCP server

Port `9090`, path `/mcp`, stateless. Four read-only tools:

| Tool | What it does |
|---|---|
| `searchProducts` | Search by words and optional category |
| `getProduct` | Full product details |
| `checkStock` | Units per size |
| `getPolicy` | One store policy |

A `404` from the API is reported as "not found". A `401` or `403` is reported as a setup problem and
logged, so a wrong or missing key never looks like a missing product.

| Env var | Default | Purpose |
|---|---|---|
| `PRODUCTS_API_URL` | `http://localhost:8080/api/v1` | The Products API. From the Resource on WSO2 Cloud |
| `PRODUCTS_API_KEY` | None | Sent as `X-API-Key` on every API call. From the Resource on WSO2 Cloud |

## Product Help Agent

Serves `POST /chat` on port `8000` (`{"message", "session_id"}` in, `{"response", "session_id"}` out) and
`GET /health`. Agent Manager starts it with `python main.py`.

| Env var | Required | Purpose |
|---|---|---|
| `PRODUCTS_MCP_URL` | Yes | The MCP gateway URL plus `/mcp` |
| `MCP_API_KEY` | When the MCP gateway checks keys | Sent as `X-API-Key`. Store it as a secret |
| `LLM_PROVIDER_URL`, `LLM_PROVIDER_KEY` | When `USE_LLM_PROVIDER=true` | Injected by Agent Manager from the bound Anthropic provider |
| `USE_LLM_PROVIDER` | No, default `true` | `false` for a local run straight against Anthropic |
| `ANTHROPIC_API_KEY` | When `USE_LLM_PROVIDER=false` | Local runs only |
| `MODEL` | No, default `claude-opus-5-5` | Claude model |
| `MAX_TOKENS` | No, default `16000` | Cap on each reply |
| `STORE_NAME` | No, default `Summit Outdoor` | Name used in the instructions |

The agent sends the provider key in `API-Key`, which the Agent Manager LLM gateway reads, and calls
`<LLM_PROVIDER_URL>/v1/messages` (a trailing `/v1` on the URL is dropped first).

## Run locally

```bash
cd products-api && bal run
```

```bash
cd products-mcp && bal run
```

```bash
cd agent
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
export PRODUCTS_MCP_URL=http://localhost:9090/mcp USE_LLM_PROVIDER=false ANTHROPIC_API_KEY=<your-key>
python main.py
```

```bash
curl -X POST http://localhost:8000/chat -H "Content-Type: application/json" \
  -d '{"message": "Is the Trailblazer jacket in stock in size M?", "session_id": "demo"}'
```
