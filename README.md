# Kranger

Kranger is a terminal UI for watching a Kubernetes cluster's topology in real time — namespaces, workloads, and how they connect to each other — without leaving your terminal or reaching for a browser.

It's not trying to replace `k9s` or the Kubernetes dashboard. It's a smaller, more focused tool: a compact, at-a-glance view of what's running, whether it's healthy, and how the pieces relate, refreshed on demand.

## Why this exists

Most Kubernetes tools are built for *doing things* — editing resources, execing into pods, tailing logs, deleting what's broken. Kranger isn't that. It's built for *seeing things* — a fast, safe, read-only view of what's running and whether it's healthy, before you go reach for a tool that actually does something.

It never writes to your cluster. It can't. There's no edit, no delete, no exec — only discovery and rendering. That's not a missing feature, it's the point: a visibility layer you can glance at without any risk of changing anything, especially useful against a cluster you don't want to touch carelessly.

If you need to operate on your cluster, you still want `kubectl`, `k9s`, or Lens. Kranger is what you check first.

## What it actually shows

- Namespaces, grouped visually, each containing the resources inside them
- The Deployment → ReplicaSet → Pod → Service chain, drawn as connected boxes
- A live ready-ratio bar on each group (`[████] 9/9`), pulled straight from the cluster
- Restart counts (`⟳3`) when pods have been restarting
- Node health (Ready / Down), colored accordingly
- A running total of everything in the cluster along the bottom

Everything you see is live — Kranger queries the Kubernetes API directly each time you refresh, the same way `kubectl` does.

## Installing it

You need either Go or Docker. Pick whichever you already have.

### If you have Docker

This is the easiest path — no Go toolchain, no version conflicts, nothing to configure beyond mounting your kubeconfig:

```bash
docker run -it --rm -v ~/.kube:/root/.kube:ro ghcr.io/shauryan/kranger:latest
```

That's it. It reads your existing kubeconfig (read-only, it never touches it) and starts.

### If you have Go

Kranger's dependencies need Go 1.24 or newer — mainly because of standard library packages (`slices`, `maps`, `cmp`) that the Kubernetes client libraries rely on. If you're not sure what version you have:

```bash
go version
```

If it's 1.24+, install directly:

```bash
go install github.com/Shauryan/kranger@latest
```

This puts a `kranger` binary in your `$GOPATH/bin` (usually `~/go/bin`). Make sure that's on your `PATH`.

If your Go is older, or you don't have Go at all, there's an install script that handles both — checks your version, installs a current one if needed, and runs `go install` for you:

```bash
curl -fsSL https://raw.githubusercontent.com/Shauryan/kranger/main/install.sh | bash
```

## Running it

```bash
kranger
```

That's the whole interface. Kranger reads your current `kubectl` context, so whatever cluster `kubectl get pods` talks to is what you'll see. If you need to point it at a different cluster, switch contexts first:

```bash
kubectl config use-context <some-other-cluster>
kranger
```

Once it's running:

- Press **Enter** to refresh the view
- Type **q** and press Enter to quit

There's no auto-refresh timer by design — Kranger only re-queries the cluster when you ask it to, so it doesn't hammer the API server in the background while you're just looking at it.

## Building from source

```bash
git clone https://github.com/Shauryan/kranger.git
cd kranger
go build -o kranger .
./kranger
```

## What's not there yet

Being upfront about the current limitations, rather than letting you find out the hard way:

- **Only one Node renders.** If your cluster has more than one Node, the resource count at the bottom will show the real number, but the topology itself only draws the first one it finds. Multi-node clusters work fine functionally — the visual just doesn't reflect all of them yet.
- **StatefulSets show up, but without a health bar.** They're discovered and placed in the topology correctly, but they don't yet get a ready-ratio bar the way Deployments and Pods do.
- **DaemonSets, Ingress, ConfigMaps, and most other resource kinds aren't discovered at all.** Right now Kranger focuses on the core Deployment/ReplicaSet/Pod/Service/StatefulSet chain.
- **Large clusters are mostly untested.** It's been run against clusters with roughly 50 resources without trouble, but nothing bigger has been tried yet.

None of these are architectural dead ends — they're just not built yet.

## Requirements

- A working `kubeconfig` (the same one `kubectl` uses)
- Go 1.24+ if building from source, or Docker if using the image

## Contributing

If something looks wrong or you hit a case that doesn't render right, open an issue with what your cluster looked like at the time — that's usually enough to track it down.

## License

MIT
