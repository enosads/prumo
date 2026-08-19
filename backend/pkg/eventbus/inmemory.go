package eventbus

import (
	"context"
	"sync"
)

// InMemoryBus is a synchronous, in-process implementation of Bus.
// Publish blocks until all handlers for the event type have returned.
// Handler errors are collected and returned as a joined error.
type InMemoryBus struct {
	mu       sync.RWMutex
	handlers map[string][]registeredHandler
	nextID   uint64
}

type registeredHandler struct {
	id      uint64
	handler Handler
}

// NewInMemoryBus constructs a ready-to-use InMemoryBus.
func NewInMemoryBus() *InMemoryBus {
	return &InMemoryBus{
		handlers: make(map[string][]registeredHandler),
	}
}

// Publish calls all handlers registered for event.EventType() in registration
// order. All handlers are called even if one returns an error; errors are
// joined and returned together.
func (b *InMemoryBus) Publish(ctx context.Context, event Event) error {
	b.mu.RLock()
	hs := make([]registeredHandler, len(b.handlers[event.EventType()]))
	copy(hs, b.handlers[event.EventType()])
	b.mu.RUnlock()

	var errs []error
	for _, rh := range hs {
		if err := rh.handler(ctx, event); err != nil {
			errs = append(errs, err)
		}
	}
	return joinErrors(errs)
}

// Subscribe registers h for events of the given eventType.
// Calling the returned function removes the handler.
func (b *InMemoryBus) Subscribe(eventType string, h Handler) (unsubscribe func()) {
	b.mu.Lock()
	b.nextID++
	id := b.nextID
	b.handlers[eventType] = append(b.handlers[eventType], registeredHandler{id: id, handler: h})
	b.mu.Unlock()

	return func() {
		b.mu.Lock()
		defer b.mu.Unlock()
		hs := b.handlers[eventType]
		for i, rh := range hs {
			if rh.id == id {
				b.handlers[eventType] = append(hs[:i], hs[i+1:]...)
				return
			}
		}
	}
}

func joinErrors(errs []error) error {
	switch len(errs) {
	case 0:
		return nil
	case 1:
		return errs[0]
	default:
		return &multiError{errs: errs}
	}
}

type multiError struct{ errs []error }

func (e *multiError) Error() string {
	msg := e.errs[0].Error()
	for _, err := range e.errs[1:] {
		msg += "; " + err.Error()
	}
	return msg
}

func (e *multiError) Unwrap() []error { return e.errs }
