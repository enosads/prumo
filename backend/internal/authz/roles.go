package authz

const (
	RoleOwner  = "owner"
	RoleAdmin  = "admin"
	RoleMember = "member"
	RoleViewer = "viewer"
)

func CanManageFamily(role string) bool {
	return role == RoleOwner || role == RoleAdmin
}

func CanWriteFinancials(role string) bool {
	return role == RoleOwner || role == RoleAdmin || role == RoleMember
}

func CanViewFinancials(role string) bool {
	return role == RoleOwner || role == RoleAdmin || role == RoleMember || role == RoleViewer
}
