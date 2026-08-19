package eventbus

import "context"

// Event is the minimal contract for publishable domain events.
type Event interface {
	EventType() string
}

// Handler is a callback invoked by the bus for each matching event.
type Handler func(ctx context.Context, event Event) error

// Publisher sends events to all registered subscribers.
type Publisher interface {
	Publish(ctx context.Context, event Event) error
}

// Subscriber registers handlers for specific event types.
type Subscriber interface {
	Subscribe(eventType string, h Handler) (unsubscribe func())
}

// Bus combines publishing and subscribing.
type Bus interface {
	Publisher
	Subscriber
}
