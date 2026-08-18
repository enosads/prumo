-- name: CreateAIConversation :one
INSERT INTO ai_conversations (
    family_id, user_id, title
) VALUES (
    $1, $2, $3
)
RETURNING *;

-- name: ListAIConversationsByFamilyID :many
SELECT * FROM ai_conversations
WHERE family_id = $1 AND user_id = $2
ORDER BY updated_at DESC;

-- name: GetAIConversationByID :one
SELECT * FROM ai_conversations
WHERE id = $1 AND family_id = $2;

-- name: CreateAIMessage :one
INSERT INTO ai_messages (
    conversation_id, role, content, tool_calls, tool_call_id
) VALUES (
    $1, $2, $3, $4, $5
)
RETURNING *;

-- name: ListAIMessagesByConversationID :many
SELECT * FROM ai_messages
WHERE conversation_id = $1
ORDER BY created_at ASC;

-- name: CreateAIToolExecution :one
INSERT INTO ai_tool_executions (
    conversation_id, family_id, user_id, tool_name, parameters, status, approval_token
) VALUES (
    $1, $2, $3, $4, $5, $6, $7
)
RETURNING *;

-- name: GetAIToolExecutionByToken :one
SELECT * FROM ai_tool_executions
WHERE approval_token = $1 AND status = 'pending_approval';

-- name: UpdateAIToolExecutionStatus :one
UPDATE ai_tool_executions
SET status = $2, result = $3, executed_at = now()
WHERE id = $1
RETURNING *;
