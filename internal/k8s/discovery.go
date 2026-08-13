package k8s

import (
	"context"
	"fmt"
	"time"

	"kranger/internal/model"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/labels"
)

type Discovery struct {
	Client *Client
}

func NewDiscovery(client *Client) *Discovery {
	return &Discovery{
		Client: client,
	}
}

func age(t time.Time) string {
	if t.IsZero() {
		return "-"
	}

	d := time.Since(t)

	switch {
	case d < time.Minute:
		return fmt.Sprintf("%ds", int(d.Seconds()))
	case d < time.Hour:
		return fmt.Sprintf("%dm", int(d.Minutes()))
	case d < 24*time.Hour:
		return fmt.Sprintf("%dh", int(d.Hours()))
	case d < 30*24*time.Hour:
		return fmt.Sprintf("%dd", int(d.Hours()/24))
	default:
		return fmt.Sprintf("%dmo", int(d.Hours()/(24*30)))
	}
}

func resourceID(kind model.ResourceKind, namespace, name string) string {
	if namespace == "" {
		return fmt.Sprintf("%s/%s", kind, name)
	}

	return fmt.Sprintf("%s/%s/%s", kind, namespace, name)
}

func (d *Discovery) Discover(ctx context.Context) (*model.ClusterState, error) {
	state := model.NewClusterState()

	// --------------------------------------------------
	// Namespaces
	// --------------------------------------------------

	namespaces, err := d.Client.Clientset.CoreV1().
		Namespaces().
		List(ctx, metav1.ListOptions{})

	if err != nil {
		return nil, fmt.Errorf("list namespaces: %w", err)
	}

	for _, ns := range namespaces.Items {
		state.Namespaces = append(state.Namespaces, model.Resource{
			ID:     resourceID(model.KindNamespace, "", ns.Name),
			Kind:   model.KindNamespace,
			Name:   ns.Name,
			Status: string(ns.Status.Phase),
			Age:    age(ns.CreationTimestamp.Time),
		})
	}

	// --------------------------------------------------
	// Nodes
	// --------------------------------------------------

	nodes, err := d.Client.Clientset.CoreV1().
		Nodes().
		List(ctx, metav1.ListOptions{})

	if err != nil {
		return nil, fmt.Errorf("list nodes: %w", err)
	}

	for _, node := range nodes.Items {
		status := "Unknown"

		for _, condition := range node.Status.Conditions {
			if condition.Type == "Ready" {
				status = string(condition.Status)
				break
			}
		}

		state.Nodes = append(state.Nodes, model.Resource{
			ID:     resourceID(model.KindNode, "", node.Name),
			Kind:   model.KindNode,
			Name:   node.Name,
			Status: status,
			Age:    age(node.CreationTimestamp.Time),
		})
	}

	// --------------------------------------------------
	// Pods
	// --------------------------------------------------

	pods, err := d.Client.Clientset.CoreV1().
		Pods("").
		List(ctx, metav1.ListOptions{})

	if err != nil {
		return nil, fmt.Errorf("list pods: %w", err)
	}

	for _, pod := range pods.Items {

		restarts := 0
		for _, cs := range pod.Status.ContainerStatuses {
			restarts += int(cs.RestartCount)
		}

		state.Pods = append(state.Pods, model.Resource{
			ID:           resourceID(model.KindPod, pod.Namespace, pod.Name),
			Kind:         model.KindPod,
			Name:         pod.Name,
			Namespace:    pod.Namespace,
			Status:       string(pod.Status.Phase),
			Age:          age(pod.CreationTimestamp.Time),
			RestartCount: restarts,
		})

		// Pod -> Namespace
		state.Relationships = append(
			state.Relationships,
			model.Relationship{
				SourceID: resourceID(model.KindNamespace, "", pod.Namespace),
				TargetID: resourceID(model.KindPod, pod.Namespace, pod.Name),
				Type:     model.RelationContains,
			},
		)

		// Pod -> Node
		if pod.Spec.NodeName != "" {
			state.Relationships = append(
				state.Relationships,
				model.Relationship{
					SourceID: resourceID(model.KindPod, pod.Namespace, pod.Name),
					TargetID: resourceID(model.KindNode, "", pod.Spec.NodeName),
					Type:     model.RelationRunsOn,
				},
			)
		}

		// Pod -> ReplicaSet / Deployment ownership
		for _, owner := range pod.OwnerReferences {
			if owner.Kind == "ReplicaSet" {
				rsID := resourceID(
					model.KindReplicaSet,
					pod.Namespace,
					owner.Name,
				)

				state.Relationships = append(
					state.Relationships,
					model.Relationship{
						SourceID: rsID,
						TargetID: resourceID(
							model.KindPod,
							pod.Namespace,
							pod.Name,
						),
						Type: model.RelationOwns,
					},
				)
			}
		}
	}

	// --------------------------------------------------
	// Deployments
	// --------------------------------------------------

	deployments, err := d.Client.Clientset.AppsV1().
		Deployments("").
		List(ctx, metav1.ListOptions{})

	if err != nil {
		return nil, fmt.Errorf("list deployments: %w", err)
	}

	for _, deployment := range deployments.Items {
		state.Deployments = append(state.Deployments, model.Resource{
			ID:        resourceID(model.KindDeployment, deployment.Namespace, deployment.Name),
			Kind:      model.KindDeployment,
			Name:      deployment.Name,
			Namespace: deployment.Namespace,
			Status: fmt.Sprintf(
				"%d/%d ready",
				deployment.Status.ReadyReplicas,
				replicasOrZero(deployment.Spec.Replicas),
			),
			Age: age(deployment.CreationTimestamp.Time),
		})

		// Deployment -> Namespace
		state.Relationships = append(
			state.Relationships,
			model.Relationship{
				SourceID: resourceID(model.KindNamespace, "", deployment.Namespace),
				TargetID: resourceID(
					model.KindDeployment,
					deployment.Namespace,
					deployment.Name,
				),
				Type: model.RelationContains,
			},
		)

		// Deployment -> ReplicaSet
		rsList, err := d.Client.Clientset.AppsV1().
			ReplicaSets(deployment.Namespace).
			List(ctx, metav1.ListOptions{})

		if err != nil {
			return nil, fmt.Errorf(
				"list replicasets for deployment %s: %w",
				deployment.Name,
				err,
			)
		}

		for _, rs := range rsList.Items {
			for _, owner := range rs.OwnerReferences {
				if owner.Kind == "Deployment" &&
					owner.Name == deployment.Name {

					state.ReplicaSets = append(
						state.ReplicaSets,
						model.Resource{
							ID: resourceID(
								model.KindReplicaSet,
								rs.Namespace,
								rs.Name,
							),
							Kind:      model.KindReplicaSet,
							Name:      rs.Name,
							Namespace: rs.Namespace,
							Status: fmt.Sprintf(
								"%d/%d ready",
								rs.Status.ReadyReplicas,
								replicasOrZero(rs.Spec.Replicas),
							),
							Age: age(rs.CreationTimestamp.Time),
						},
					)

					state.Relationships = append(
						state.Relationships,
						model.Relationship{
							SourceID: resourceID(
								model.KindDeployment,
								deployment.Namespace,
								deployment.Name,
							),
							TargetID: resourceID(
								model.KindReplicaSet,
								rs.Namespace,
								rs.Name,
							),
							Type: model.RelationOwns,
						},
					)
				}
			}
		}
	}

	// --------------------------------------------------
	// Services
	// --------------------------------------------------

	services, err := d.Client.Clientset.CoreV1().
		Services("").
		List(ctx, metav1.ListOptions{})

	if err != nil {
		return nil, fmt.Errorf("list services: %w", err)
	}

	for _, service := range services.Items {
		state.Services = append(state.Services, model.Resource{
			ID:        resourceID(model.KindService, service.Namespace, service.Name),
			Kind:      model.KindService,
			Name:      service.Name,
			Namespace: service.Namespace,
			Status:    string(service.Spec.Type),
			Age:       age(service.CreationTimestamp.Time),
		})

		// Service -> Namespace
		state.Relationships = append(
			state.Relationships,
			model.Relationship{
				SourceID: resourceID(model.KindNamespace, "", service.Namespace),
				TargetID: resourceID(
					model.KindService,
					service.Namespace,
					service.Name,
				),
				Type: model.RelationContains,
			},
		)

		// Service -> Pods through selector
		if len(service.Spec.Selector) > 0 {
			selector := labels.Set(service.Spec.Selector).AsSelector()

			selectedPods, err := d.Client.Clientset.CoreV1().
				Pods(service.Namespace).
				List(ctx, metav1.ListOptions{
					LabelSelector: selector.String(),
				})

			if err != nil {
				return nil, fmt.Errorf(
					"find service endpoints for %s: %w",
					service.Name,
					err,
				)
			}

			for _, pod := range selectedPods.Items {
				state.Relationships = append(
					state.Relationships,
					model.Relationship{
						SourceID: resourceID(
							model.KindService,
							service.Namespace,
							service.Name,
						),
						TargetID: resourceID(
							model.KindPod,
							pod.Namespace,
							pod.Name,
						),
						Type: model.RelationSelects,
					},
				)
			}
		}
	}

	return state, nil
}

// replicasOrZero safely dereferences a *int32 replica
// count, which the Kubernetes API leaves nil when unset.
func replicasOrZero(r *int32) int32 {
	if r == nil {
		return 0
	}
	return *r
}
