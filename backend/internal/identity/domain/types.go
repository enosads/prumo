package domain

import (
	"time"

	"github.com/google/uuid"
)

type Role string

const (
	RoleOwner  Role = "owner"
	RoleAdmin  Role = "admin"
	RoleMember Role = "member"
	RoleViewer Role = "viewer"
)

type User struct {
	ID        uuid.UUID
	Email     string
	FullName  string
	AvatarURL *string
	IsActive  bool
	CreatedAt time.Time
	UpdatedAt time.Time
}

type Family struct {
	ID           uuid.UUID
	Name         string
	BaseCurrency string
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

type FamilyMember struct {
	ID        uuid.UUID
	FamilyID  uuid.UUID
	UserID    uuid.UUID
	Role      Role
	Nickname  *string
	JoinedAt  time.Time
	Email     string
	FullName  string
	AvatarURL *string
}
