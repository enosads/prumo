package api

import (
	"github.com/danielgtaylor/huma/v2"
)

func httpErrorBadRequest(msg string) error {
	return huma.Error400BadRequest(msg)
}

func httpErrorUnauthorized(msg string) error {
	return huma.Error401Unauthorized(msg)
}

func httpErrorForbidden(msg string) error {
	return huma.Error403Forbidden(msg)
}

func httpErrorNotFound(msg string) error {
	return huma.Error404NotFound(msg)
}

func httpErrorConflict(msg string) error {
	return huma.Error409Conflict(msg)
}

func httpErrorUnprocessable(msg string) error {
	return huma.Error422UnprocessableEntity(msg)
}

func httpErrorInternal(msg string) error {
	return huma.Error500InternalServerError(msg)
}
