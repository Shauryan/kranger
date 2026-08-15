# ---------- Build stage ----------
FROM golang:latest AS build

WORKDIR /src

COPY go.mod go.sum ./
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 go build -o /kranger .

# ---------- Final stage ----------
FROM debian:bookworm-slim

# ca-certificates needed for TLS to the Kubernetes API server.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /kranger /usr/local/bin/kranger

# NewClient() reads $HOME/.kube/config, so HOME must point
# somewhere the mounted kubeconfig will actually be found.
ENV HOME=/root

ENTRYPOINT ["kranger"]
