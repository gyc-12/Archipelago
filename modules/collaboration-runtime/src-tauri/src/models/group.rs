use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupChatInfo {
    pub id: i32,
    pub name: String,
    pub folder_id: Option<i32>,
    pub folder_path: Option<String>,
    pub primary_agent_id: Option<i32>,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupAgentInfo {
    pub id: i32,
    pub group_id: i32,
    pub agent_type: String,
    pub role: String,
    pub conversation_id: Option<i32>,
    pub connection_id: Option<String>,
    pub working_dir: String,
    pub created_at: String,
    pub updated_at: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct GroupChatWithAgents {
    pub group: GroupChatInfo,
    pub agents: Vec<GroupAgentInfo>,
}

impl From<crate::db::entities::group_chat::Model> for GroupChatInfo {
    fn from(m: crate::db::entities::group_chat::Model) -> Self {
        Self {
            id: m.id,
            name: m.name,
            folder_id: m.folder_id,
            folder_path: m.folder_path,
            primary_agent_id: m.primary_agent_id,
            created_at: m.created_at.to_rfc3339(),
            updated_at: m.updated_at.to_rfc3339(),
        }
    }
}

impl From<crate::db::entities::group_agent::Model> for GroupAgentInfo {
    fn from(m: crate::db::entities::group_agent::Model) -> Self {
        Self {
            id: m.id,
            group_id: m.group_id,
            agent_type: m.agent_type,
            role: m.role,
            conversation_id: m.conversation_id,
            connection_id: m.connection_id,
            working_dir: m.working_dir,
            created_at: m.created_at.to_rfc3339(),
            updated_at: m.updated_at.to_rfc3339(),
        }
    }
}
