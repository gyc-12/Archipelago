use std::collections::HashSet;

use sea_orm::{ColumnTrait, EntityTrait, QueryFilter};
use serde::{Deserialize, Serialize};

use crate::acp::error::AcpError;
use crate::acp::types::{GroupCollaborationMemberInfo, PromptInputBlock};
use crate::db::entities::{group_agent, group_chat};
use crate::db::service::group_service;
use crate::db::AppDatabase;
use crate::models::agent::AgentType;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum RequestedMention {
    All,
    Agent(AgentType),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum GroupCollaborationMode {
    #[default]
    Mention,
    Auto,
}

#[derive(Debug, Clone, PartialEq, Eq)]
struct CollaborationMember {
    agent_id: i32,
    agent_type: AgentType,
    role: String,
    working_dir: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct GroupCollaborationPlan {
    pub group_id: i32,
    pub group_name: String,
    pub primary_agent_id: i32,
    pub requested_mentions: Vec<String>,
    pub invalid_mentions: Vec<String>,
    pub members: Vec<GroupCollaborationMemberInfo>,
}

#[derive(Debug, Clone)]
pub struct GroupCollaborationEnrichment {
    pub blocks: Vec<PromptInputBlock>,
    pub plan: Option<GroupCollaborationPlan>,
}

pub async fn enrich_group_collaboration_prompt(
    db: &AppDatabase,
    blocks: Vec<PromptInputBlock>,
    conversation_id: Option<i32>,
) -> Result<Vec<PromptInputBlock>, AcpError> {
    Ok(analyze_group_collaboration_prompt_with_mode(
        db,
        blocks,
        conversation_id,
        GroupCollaborationMode::Mention,
    )
    .await?
    .blocks)
}

pub async fn enrich_group_collaboration_prompt_with_mode(
    db: &AppDatabase,
    blocks: Vec<PromptInputBlock>,
    conversation_id: Option<i32>,
    mode: GroupCollaborationMode,
) -> Result<Vec<PromptInputBlock>, AcpError> {
    Ok(
        analyze_group_collaboration_prompt_with_mode(db, blocks, conversation_id, mode)
            .await?
            .blocks,
    )
}

pub async fn analyze_group_collaboration_prompt(
    db: &AppDatabase,
    blocks: Vec<PromptInputBlock>,
    conversation_id: Option<i32>,
) -> Result<GroupCollaborationEnrichment, AcpError> {
    analyze_group_collaboration_prompt_with_mode(
        db,
        blocks,
        conversation_id,
        GroupCollaborationMode::Mention,
    )
    .await
}

pub async fn analyze_group_collaboration_prompt_with_mode(
    db: &AppDatabase,
    blocks: Vec<PromptInputBlock>,
    conversation_id: Option<i32>,
    mode: GroupCollaborationMode,
) -> Result<GroupCollaborationEnrichment, AcpError> {
    let Some(conversation_id) = conversation_id else {
        return Ok(GroupCollaborationEnrichment { blocks, plan: None });
    };

    let requested = requested_members_for_mode(mode, &blocks);
    if requested.is_empty() {
        return Ok(GroupCollaborationEnrichment { blocks, plan: None });
    }

    let current_agents = group_service::list_agents_by_conversation(&db.conn, conversation_id)
        .await
        .map_err(|e| AcpError::protocol(e.to_string()))?;
    let Some(current_agent) = current_agents.first() else {
        return Ok(GroupCollaborationEnrichment { blocks, plan: None });
    };

    let Some(group) = group_chat::Entity::find_by_id(current_agent.group_id)
        .filter(group_chat::Column::DeletedAt.is_null())
        .one(&db.conn)
        .await
        .map_err(|e| AcpError::protocol(e.to_string()))?
    else {
        return Ok(GroupCollaborationEnrichment { blocks, plan: None });
    };

    if group.primary_agent_id != Some(current_agent.id) {
        return Ok(GroupCollaborationEnrichment { blocks, plan: None });
    }

    let group_agents = group_service::list_agents_by_group(&db.conn, group.id)
        .await
        .map_err(|e| AcpError::protocol(e.to_string()))?;
    let (members, invalid_mentions) =
        resolve_requested_members(&requested, &group_agents, current_agent.id);
    if members.is_empty() {
        return Ok(GroupCollaborationEnrichment {
            blocks,
            plan: Some(GroupCollaborationPlan {
                group_id: group.id,
                group_name: group.name,
                primary_agent_id: current_agent.id,
                requested_mentions: requested.iter().map(requested_mention_label).collect(),
                invalid_mentions,
                members: Vec::new(),
            }),
        });
    }

    let mut enriched = blocks;
    enriched.push(PromptInputBlock::Text {
        text: build_orchestrator_context(mode, &group, current_agent, &members),
    });
    Ok(GroupCollaborationEnrichment {
        blocks: enriched,
        plan: Some(GroupCollaborationPlan {
            group_id: group.id,
            group_name: group.name,
            primary_agent_id: current_agent.id,
            requested_mentions: requested.iter().map(requested_mention_label).collect(),
            invalid_mentions,
            members: members
                .iter()
                .map(|member| GroupCollaborationMemberInfo {
                    agent_id: member.agent_id,
                    agent_type: member.agent_type,
                    role: member.role.clone(),
                    working_dir: member.working_dir.clone(),
                })
                .collect(),
        }),
    })
}

fn requested_members_for_mode(
    mode: GroupCollaborationMode,
    blocks: &[PromptInputBlock],
) -> Vec<RequestedMention> {
    let requested = extract_requested_mentions(blocks);
    match mode {
        GroupCollaborationMode::Mention => requested,
        GroupCollaborationMode::Auto if requested.is_empty() => vec![RequestedMention::All],
        GroupCollaborationMode::Auto => requested,
    }
}

fn extract_requested_mentions(blocks: &[PromptInputBlock]) -> Vec<RequestedMention> {
    let mut requested = Vec::new();
    let mut seen_agents = HashSet::new();
    let mut saw_all = false;

    for block in blocks {
        let PromptInputBlock::Text { text } = block else {
            continue;
        };
        for raw in scan_mentions(text) {
            if is_all_mention(&raw) {
                if !saw_all {
                    requested.push(RequestedMention::All);
                    saw_all = true;
                }
                continue;
            }
            if let Some(agent_type) = mention_to_agent_type(&raw) {
                if seen_agents.insert(agent_type) {
                    requested.push(RequestedMention::Agent(agent_type));
                }
            }
        }
    }

    requested
}

fn scan_mentions(text: &str) -> Vec<String> {
    let mut mentions = Vec::new();
    let chars = text.char_indices().collect::<Vec<_>>();
    let mut idx = 0;

    while idx < chars.len() {
        let (_, ch) = chars[idx];
        if ch != '@' {
            idx += 1;
            continue;
        }

        idx += 1;
        let start_idx = idx;
        while idx < chars.len() {
            let (_, c) = chars[idx];
            if c.is_alphanumeric() || c == '_' || c == '-' {
                idx += 1;
                continue;
            }
            break;
        }

        if idx > start_idx {
            let start = chars[start_idx].0;
            let end = chars
                .get(idx)
                .map(|(pos, _)| *pos)
                .unwrap_or_else(|| text.len());
            mentions.push(normalize_mention(&text[start..end]));
        }
    }

    mentions
}

fn normalize_mention(raw: &str) -> String {
    raw.trim()
        .trim_start_matches('@')
        .trim_matches(|c: char| !(c.is_alphanumeric() || c == '_' || c == '-'))
        .replace('-', "_")
        .to_lowercase()
}

fn is_all_mention(raw: &str) -> bool {
    matches!(raw, "all" | "everyone" | "agents" | "team")
}

fn mention_to_agent_type(raw: &str) -> Option<AgentType> {
    match raw {
        "claude" | "claude_code" | "claudecode" | "claude_cli" => Some(AgentType::ClaudeCode),
        "codex" | "codex_cli" => Some(AgentType::Codex),
        "gemini" | "gemini_cli" => Some(AgentType::Gemini),
        "open_code" | "opencode" | "open_code_cli" | "opencode_cli" => Some(AgentType::OpenCode),
        "open_claw" | "openclaw" | "claw" => Some(AgentType::OpenClaw),
        "cline" => Some(AgentType::Cline),
        _ => None,
    }
}

fn parse_agent_type(raw: &str) -> Option<AgentType> {
    serde_json::from_value(serde_json::Value::String(raw.to_string())).ok()
}

fn serialize_agent_type(agent_type: AgentType) -> String {
    serde_json::to_value(agent_type)
        .ok()
        .and_then(|v| v.as_str().map(ToOwned::to_owned))
        .unwrap_or_else(|| agent_type.to_string())
}

fn requested_mention_label(item: &RequestedMention) -> String {
    match item {
        RequestedMention::All => "all".to_string(),
        RequestedMention::Agent(agent_type) => serialize_agent_type(*agent_type),
    }
}

fn resolve_requested_members(
    requested: &[RequestedMention],
    group_agents: &[group_agent::Model],
    primary_agent_id: i32,
) -> (Vec<CollaborationMember>, Vec<String>) {
    let mut resolved = Vec::new();
    let mut seen = HashSet::new();
    let mut invalid_mentions = Vec::new();

    for item in requested {
        match item {
            RequestedMention::All => {
                let before = resolved.len();
                for agent in group_agents {
                    push_member_if_available(agent, primary_agent_id, &mut seen, &mut resolved);
                }
                if resolved.len() == before {
                    invalid_mentions.push("all".to_string());
                }
            }
            RequestedMention::Agent(agent_type) => {
                if let Some(agent) = group_agents
                    .iter()
                    .find(|candidate| parse_agent_type(&candidate.agent_type) == Some(*agent_type))
                {
                    push_member_if_available(agent, primary_agent_id, &mut seen, &mut resolved);
                } else {
                    invalid_mentions.push(serialize_agent_type(*agent_type));
                }
            }
        }
    }

    (resolved, invalid_mentions)
}

fn push_member_if_available(
    agent: &group_agent::Model,
    primary_agent_id: i32,
    seen: &mut HashSet<AgentType>,
    resolved: &mut Vec<CollaborationMember>,
) {
    if agent.id == primary_agent_id {
        return;
    }
    let Some(agent_type) = parse_agent_type(&agent.agent_type) else {
        return;
    };
    if !seen.insert(agent_type) {
        return;
    }
    resolved.push(CollaborationMember {
        agent_id: agent.id,
        agent_type,
        role: agent.role.clone(),
        working_dir: agent.working_dir.clone(),
    });
}

fn build_orchestrator_context(
    mode: GroupCollaborationMode,
    group: &group_chat::Model,
    primary_agent: &group_agent::Model,
    members: &[CollaborationMember],
) -> String {
    let mut context = String::from("\n\n<archipelago_group_collaboration>\n");
    context.push_str("You are the Orchestrator for this Archipelago group chat.\n");
    match mode {
        GroupCollaborationMode::Mention => {
            context.push_str("The user's message mentioned group members. Coordinate the work through the delegate_to_agent tool before your final answer.\n");
        }
        GroupCollaborationMode::Auto => {
            context.push_str("The user submitted this request from Island group chat mode. Understand the user's intent, decompose the work by member role, and coordinate through the delegate_to_agent tool before your final answer.\n");
        }
    }
    context.push_str(&format!("Group: {}\n", sanitize_context_value(&group.name)));
    if let Some(path) = group.folder_path.as_deref() {
        context.push_str(&format!("Workspace: {}\n", sanitize_context_value(path)));
    }
    context.push_str(&format!(
        "Orchestrator role: {}\n",
        sanitize_context_value(&primary_agent.role)
    ));
    context.push_str("Delegation order:\n");
    for (index, member) in members.iter().enumerate() {
        context.push_str(&format!(
            "{}. agent_type: \"{}\"; role: \"{}\"; working_dir: \"{}\"\n",
            index + 1,
            serialize_agent_type(member.agent_type),
            sanitize_context_value(&member.role),
            sanitize_context_value(&member.working_dir)
        ));
    }
    context.push_str("Instructions:\n");
    context.push_str("- Call the delegation tool once for each listed member, in the exact order above. The tool is named delegate_to_agent; if your host shows MCP-prefixed tools, use the visible equivalent such as mcp__archipelago-delegate__delegate_to_agent or archipelago-delegate/delegate_to_agent.\n");
    context.push_str("- Use the listed agent_type and working_dir for each call.\n");
    context.push_str("- Give each member a focused task derived from the user's message and that member's role.\n");
    context.push_str("- Briefly explain your decomposition before or while delegating so the chat stream shows the collaboration flow.\n");
    context.push_str("- Wait for every delegated result, then summarize each member's contribution and provide one integrated final answer.\n");
    context.push_str("- Do not delegate to yourself. If delegate_to_agent is unavailable, say so and continue with the best single-agent answer.\n");
    context.push_str("</archipelago_group_collaboration>");
    context
}

fn sanitize_context_value(value: &str) -> String {
    value.replace("</", "<\\/")
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::db::service::group_service;
    use crate::db::test_helpers::{fresh_in_memory_db, seed_conversation, seed_folder};

    fn text_block(text: &str) -> PromptInputBlock {
        PromptInputBlock::Text {
            text: text.to_string(),
        }
    }

    #[test]
    fn extracts_mentions_in_order_and_dedupes_agents() {
        let requested = extract_requested_mentions(&[
            text_block("@codex please review with @gemini and @codex again"),
            text_block("@open-code follow up"),
        ]);

        assert_eq!(
            requested,
            vec![
                RequestedMention::Agent(AgentType::Codex),
                RequestedMention::Agent(AgentType::Gemini),
                RequestedMention::Agent(AgentType::OpenCode),
            ]
        );
    }

    #[tokio::test]
    async fn enriches_primary_group_prompt_with_requested_members() {
        let db = fresh_in_memory_db().await;
        let folder_id = seed_folder(&db, "/tmp/archipelago-group").await;
        let primary_conv = seed_conversation(&db, folder_id, AgentType::ClaudeCode).await;
        let codex_conv = seed_conversation(&db, folder_id, AgentType::Codex).await;
        let gemini_conv = seed_conversation(&db, folder_id, AgentType::Gemini).await;
        let group = group_service::create_group(
            &db.conn,
            "Planning".to_string(),
            Some(folder_id),
            Some("/tmp/archipelago-group".to_string()),
        )
        .await
        .expect("create group");
        let primary = group_service::add_agent(
            &db.conn,
            group.id,
            serialize_agent_type(AgentType::ClaudeCode),
            "Primary".to_string(),
            Some(primary_conv),
            None,
            "/tmp/archipelago-group".to_string(),
        )
        .await
        .expect("add primary");
        let codex = group_service::add_agent(
            &db.conn,
            group.id,
            serialize_agent_type(AgentType::Codex),
            "Reviewer".to_string(),
            Some(codex_conv),
            None,
            "/tmp/archipelago-group".to_string(),
        )
        .await
        .expect("add codex");
        let gemini = group_service::add_agent(
            &db.conn,
            group.id,
            serialize_agent_type(AgentType::Gemini),
            "Planner".to_string(),
            Some(gemini_conv),
            None,
            "/tmp/archipelago-group".to_string(),
        )
        .await
        .expect("add gemini");
        group_service::update_group(&db.conn, group.id, None, Some(Some(primary.id)))
            .await
            .expect("set primary");

        let enrichment = analyze_group_collaboration_prompt(
            &db,
            vec![text_block("@codex @gemini @open_code review the plan")],
            Some(primary_conv),
        )
        .await
        .expect("enrich");

        let enriched = enrichment.blocks;
        assert_eq!(enriched.len(), 2);
        let PromptInputBlock::Text { text } = &enriched[1] else {
            panic!("expected injected text block");
        };
        assert!(text.contains("delegate_to_agent"));
        assert!(text.contains("agent_type: \"codex\""));
        assert!(text.contains("agent_type: \"gemini\""));
        assert!(!text.contains("agent_type: \"claude_code\""));

        let plan = enrichment.plan.expect("expected collaboration plan");
        assert_eq!(plan.group_id, group.id);
        assert_eq!(plan.group_name, "Planning");
        assert_eq!(plan.primary_agent_id, primary.id);
        assert_eq!(
            plan.requested_mentions,
            vec!["codex", "gemini", "open_code"]
        );
        assert_eq!(plan.invalid_mentions, vec!["open_code"]);
        assert_eq!(plan.members.len(), 2);
        assert_eq!(plan.members[0].agent_id, codex.id);
        assert_eq!(plan.members[0].agent_type, AgentType::Codex);
        assert_eq!(plan.members[0].role, "Reviewer");
        assert_eq!(plan.members[1].agent_id, gemini.id);
        assert_eq!(plan.members[1].agent_type, AgentType::Gemini);
        assert_eq!(plan.members[1].role, "Planner");
    }

    #[tokio::test]
    async fn auto_mode_enriches_primary_group_prompt_with_all_non_primary_members() {
        let db = fresh_in_memory_db().await;
        let folder_id = seed_folder(&db, "/tmp/archipelago-group").await;
        let primary_conv = seed_conversation(&db, folder_id, AgentType::ClaudeCode).await;
        let codex_conv = seed_conversation(&db, folder_id, AgentType::Codex).await;
        let gemini_conv = seed_conversation(&db, folder_id, AgentType::Gemini).await;
        let group = group_service::create_group(
            &db.conn,
            "Planning".to_string(),
            Some(folder_id),
            Some("/tmp/archipelago-group".to_string()),
        )
        .await
        .expect("create group");
        let primary = group_service::add_agent(
            &db.conn,
            group.id,
            serialize_agent_type(AgentType::ClaudeCode),
            "Primary".to_string(),
            Some(primary_conv),
            None,
            "/tmp/archipelago-group".to_string(),
        )
        .await
        .expect("add primary");
        let codex = group_service::add_agent(
            &db.conn,
            group.id,
            serialize_agent_type(AgentType::Codex),
            "Reviewer".to_string(),
            Some(codex_conv),
            None,
            "/tmp/archipelago-group".to_string(),
        )
        .await
        .expect("add codex");
        let gemini = group_service::add_agent(
            &db.conn,
            group.id,
            serialize_agent_type(AgentType::Gemini),
            "Planner".to_string(),
            Some(gemini_conv),
            None,
            "/tmp/archipelago-group".to_string(),
        )
        .await
        .expect("add gemini");
        group_service::update_group(&db.conn, group.id, None, Some(Some(primary.id)))
            .await
            .expect("set primary");

        let enrichment = analyze_group_collaboration_prompt_with_mode(
            &db,
            vec![text_block("Create an implementation plan")],
            Some(primary_conv),
            GroupCollaborationMode::Auto,
        )
        .await
        .expect("enrich");

        assert_eq!(enrichment.blocks.len(), 2);
        let PromptInputBlock::Text { text } = &enrichment.blocks[1] else {
            panic!("expected injected text block");
        };
        assert!(text.contains("Island group chat mode"));
        assert!(text.contains("agent_type: \"codex\""));
        assert!(text.contains("agent_type: \"gemini\""));
        assert!(!text.contains("agent_type: \"claude_code\""));

        let plan = enrichment.plan.expect("expected collaboration plan");
        assert_eq!(plan.requested_mentions, vec!["all"]);
        assert!(plan.invalid_mentions.is_empty());
        assert_eq!(
            plan.members
                .iter()
                .map(|member| member.agent_id)
                .collect::<Vec<_>>(),
            vec![codex.id, gemini.id]
        );
    }

    #[tokio::test]
    async fn does_not_enrich_non_primary_group_agent_prompt() {
        let db = fresh_in_memory_db().await;
        let folder_id = seed_folder(&db, "/tmp/archipelago-group").await;
        let primary_conv = seed_conversation(&db, folder_id, AgentType::ClaudeCode).await;
        let codex_conv = seed_conversation(&db, folder_id, AgentType::Codex).await;
        let group = group_service::create_group(
            &db.conn,
            "Planning".to_string(),
            Some(folder_id),
            Some("/tmp/archipelago-group".to_string()),
        )
        .await
        .expect("create group");
        let primary = group_service::add_agent(
            &db.conn,
            group.id,
            serialize_agent_type(AgentType::ClaudeCode),
            "Primary".to_string(),
            Some(primary_conv),
            None,
            "/tmp/archipelago-group".to_string(),
        )
        .await
        .expect("add primary");
        group_service::add_agent(
            &db.conn,
            group.id,
            serialize_agent_type(AgentType::Codex),
            "Reviewer".to_string(),
            Some(codex_conv),
            None,
            "/tmp/archipelago-group".to_string(),
        )
        .await
        .expect("add codex");
        group_service::update_group(&db.conn, group.id, None, Some(Some(primary.id)))
            .await
            .expect("set primary");

        let enriched = enrich_group_collaboration_prompt(
            &db,
            vec![text_block("@claude @codex review the plan")],
            Some(codex_conv),
        )
        .await
        .expect("enrich");

        assert_eq!(enriched.len(), 1);
    }

    #[test]
    fn all_expands_to_non_primary_members_in_group_order() {
        let agents = vec![
            group_agent::Model {
                id: 1,
                group_id: 7,
                agent_type: serialize_agent_type(AgentType::ClaudeCode),
                role: "Primary".to_string(),
                conversation_id: Some(11),
                connection_id: None,
                working_dir: "/tmp/work".to_string(),
                created_at: chrono::Utc::now(),
                updated_at: chrono::Utc::now(),
                deleted_at: None,
            },
            group_agent::Model {
                id: 2,
                group_id: 7,
                agent_type: serialize_agent_type(AgentType::Codex),
                role: "Reviewer".to_string(),
                conversation_id: Some(12),
                connection_id: None,
                working_dir: "/tmp/work".to_string(),
                created_at: chrono::Utc::now(),
                updated_at: chrono::Utc::now(),
                deleted_at: None,
            },
            group_agent::Model {
                id: 3,
                group_id: 7,
                agent_type: serialize_agent_type(AgentType::Gemini),
                role: "Planner".to_string(),
                conversation_id: Some(13),
                connection_id: None,
                working_dir: "/tmp/work".to_string(),
                created_at: chrono::Utc::now(),
                updated_at: chrono::Utc::now(),
                deleted_at: None,
            },
        ];

        let (members, invalid_mentions) =
            resolve_requested_members(&[RequestedMention::All], &agents, 1);

        assert!(invalid_mentions.is_empty());
        assert_eq!(
            members
                .iter()
                .map(|member| member.agent_type)
                .collect::<Vec<_>>(),
            vec![AgentType::Codex, AgentType::Gemini]
        );
    }
}
