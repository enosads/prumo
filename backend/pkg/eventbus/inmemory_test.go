package eventbus

import (
	"context"
	"errors"
	"testing"
)

type testEvent struct {
	name string
}

func (e testEvent) EventType() string {
	return "TestEvent"
}

func TestInMemoryBus_PublishSubscribe(t *testing.T) {
	bus := NewInMemoryBus()
	ctx := context.Background()

	var received []string
	unsub := bus.Subscribe("TestEvent", func(ctx context.Context, e Event) error {
		te := e.(testEvent)
		received = append(received, te.name)
		return nil
	})

	err := bus.Publish(ctx, testEvent{name: "hello"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(received) != 1 || received[0] != "hello" {
		t.Fatalf("expected ['hello'], got %v", received)
	}

	unsub()

	err = bus.Publish(ctx, testEvent{name: "world"})
	if err != nil {
		t.Fatalf("unexpected error: %v", err)
	}

	if len(received) != 1 {
		t.Fatalf("handler should not have received message after unsub")
	}
}

func TestInMemoryBus_MultipleHandlersAndErrors(t *testing.T) {
	bus := NewInMemoryBus()
	ctx := context.Background()

	bus.Subscribe("TestEvent", func(ctx context.Context, e Event) error {
		return errors.New("err 1")
	})
	bus.Subscribe("TestEvent", func(ctx context.Context, e Event) error {
		return errors.New("err 2")
	})

	err := bus.Publish(ctx, testEvent{name: "test"})
	if err == nil {
		t.Fatalf("expected error, got nil")
	}
}
