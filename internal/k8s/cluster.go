package k8s

import (
	"context"
	"fmt"

	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type ClusterInfo struct {
	Version    string
	Namespaces []string
}

func (c *Client) GetClusterInfo(ctx context.Context) (*ClusterInfo, error) {
	version, err := c.Clientset.Discovery().
		ServerVersion()

	if err != nil {
		return nil, fmt.Errorf("getting Kubernetes server version: %w", err)
	}

	namespaces, err := c.Clientset.CoreV1().
		Namespaces().
		List(ctx, metav1.ListOptions{})

	if err != nil {
		return nil, fmt.Errorf("listing namespaces: %w", err)
	}

	result := &ClusterInfo{
		Version: version.GitVersion,
	}

	for _, namespace := range namespaces.Items {
		result.Namespaces = append(
			result.Namespaces,
			namespace.Name,
		)
	}

	return result, nil
}
