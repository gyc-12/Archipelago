use sea_orm::entity::prelude::*;

#[derive(Clone, Debug, PartialEq, DeriveEntityModel)]
#[sea_orm(table_name = "group_chat")]
pub struct Model {
    #[sea_orm(primary_key)]
    pub id: i32,
    pub name: String,
    pub folder_id: Option<i32>,
    pub folder_path: Option<String>,
    pub primary_agent_id: Option<i32>,
    pub created_at: DateTimeUtc,
    pub updated_at: DateTimeUtc,
    pub deleted_at: Option<DateTimeUtc>,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(has_many = "super::group_agent::Entity")]
    GroupAgents,
}

impl Related<super::group_agent::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::GroupAgents.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
