# Project Metadata Dependencies (Full)

Generated from metadata in `force-app/main/default` on 2026-02-22 by `scripts/generate-project-docs.sh`.

## Scope Summary

- Object folders: 409
- Custom objects (`__c`): 22
- Apex classes: 356
- Triggers: 21
- Flows: 141
- Relationship fields (Lookup/MasterDetail): 95

## Relationship Type Distribution

| Type | Count |
|---|---:|
| `Lookup` | 92 |
| `MasterDetail` | 3 |

## Top Target Objects by Incoming Relationships

| Target Object | Count |
|---|---:|
| `Opportunity` | 16 |
| `User` | 14 |
| `Consultor__c` | 9 |
| `Account` | 8 |
| `ClickSignEnvelope__c` | 4 |
| `Instalacao__c` | 4 |
| `Parceiro__c` | 4 |
| `ServiceResource` | 4 |
| `Case` | 3 |
| `Contract` | 3 |
| `Projeto__c` | 3 |
| `ViabilityStudy__c` | 3 |
| `ClickSignTemplate__c` | 2 |
| `FSL__Scheduling_Policy__c` | 2 |
| `Integradores__c` | 2 |
| `Lead` | 2 |
| `OperatingHours` | 2 |
| `ProposalCover__c` | 2 |
| `ClickSign__c` | 1 |
| `Contact` | 1 |
| `Feedback__c` | 1 |
| `Kit_Instalacao__c` | 1 |
| `MessagingEndUser` | 1 |
| `MessagingSession` | 1 |
| `ServiceAppointment` | 1 |
| `jif6QH2I3t7Mptz__GTM__c` | 1 |

## Top Source Objects by Outgoing Relationships

| Source Object | Count |
|---|---:|
| `Instalacao__c` | 9 |
| `Opportunity` | 8 |
| `Projeto__c` | 7 |
| `WorkOrder` | 7 |
| `Case` | 5 |
| `ClickSignSigner__c` | 5 |
| `Faturamento__c` | 5 |
| `MessagingEndUser` | 4 |
| `ServiceAppointment` | 4 |
| `ClickSign__c` | 3 |
| `LeadInteraction__c` | 3 |
| `Parceiro__c` | 3 |
| `TabelaEzeeConnect__c` | 3 |
| `ViabilityStudy__c` | 3 |
| `Activity` | 2 |
| `ClickSignEnvelope__c` | 2 |
| `Feedback__c` | 2 |
| `Lead` | 2 |
| `MessagingSession` | 2 |
| `OpportunityAttachmentLink__c` | 2 |
| `lb065_Project__c` | 2 |
| `Account` | 1 |
| `ClickSignTemplate__c` | 1 |
| `Consultor__c` | 1 |
| `ContentVersion` | 1 |
| `Integradores__c` | 1 |
| `Kit_Instalacao__c` | 1 |
| `Log__c` | 1 |
| `OpportunityLineItem` | 1 |
| `ProposalPending__c` | 1 |
| `ResourceAbsence` | 1 |
| `SetupMessagingSession__c` | 1 |
| `WorkOrderLineItem` | 1 |

## Trigger Coverage

| Trigger | SObject | File |
|---|---|---|
| `AccountTrigger` | `Account` | `force-app/main/default/triggers/AccountTrigger.trigger` |
| `AssignedResourceTrigger` | `AssignedResource` | `force-app/main/default/triggers/AssignedResourceTrigger.trigger` |
| `CaseTrigger` | `Case` | `force-app/main/default/triggers/CaseTrigger.trigger` |
| `ConsultorTrigger` | `Consultor__c` | `force-app/main/default/triggers/ConsultorTrigger.trigger` |
| `ContactTrigger` | `Contact` | `force-app/main/default/triggers/ContactTrigger.trigger` |
| `ContentDocumentLinkTrigger` | `ContentDocumentLink` | `force-app/main/default/triggers/ContentDocumentLinkTrigger.trigger` |
| `ContentVersionTrigger` | `ContentVersion` | `force-app/main/default/triggers/ContentVersionTrigger.trigger` |
| `FaturamentoTrigger` | `Faturamento__c` | `force-app/main/default/triggers/FaturamentoTrigger.trigger` |
| `InstalacaoTrigger` | `Instalacao__c` | `force-app/main/default/triggers/InstalacaoTrigger.trigger` |
| `IntegradorTrigger` | `Integradores__c` | `force-app/main/default/triggers/IntegradorTrigger.trigger` |
| `KitInstalacaoTrigger` | `Kit_Instalacao__c` | `force-app/main/default/triggers/KitInstalacaoTrigger.trigger` |
| `LeadTrigger` | `Lead` | `force-app/main/default/triggers/LeadTrigger.trigger` |
| `MessagingTrigger` | `MessagingSession` | `force-app/main/default/triggers/MessagingTrigger.trigger` |
| `OpportunityLineItemTrigger` | `OpportunityLineItem` | `force-app/main/default/triggers/OpportunityLineItemTrigger.trigger` |
| `OpportunityTrigger` | `Opportunity` | `force-app/main/default/triggers/OpportunityTrigger.trigger` |
| `ProductTrigger` | `Product2` | `force-app/main/default/triggers/ProductTrigger.trigger` |
| `ProjetoTrigger` | `Projeto__c` | `force-app/main/default/triggers/ProjetoTrigger.trigger` |
| `ProposalCoverTrigger` | `ProposalCover__c` | `force-app/main/default/triggers/ProposalCoverTrigger.trigger` |
| `ServiceAppointmentTrigger` | `ServiceAppointment` | `force-app/main/default/triggers/ServiceAppointmentTrigger.trigger` |
| `TaskTrigger` | `Task` | `force-app/main/default/triggers/TaskTrigger.trigger` |
| `ViabilityStudyTrigger` | `ViabilityStudy__c` | `force-app/main/default/triggers/ViabilityStudyTrigger.trigger` |

## Flow Record Trigger Coverage (Distinct Flow Files per Object)

| Object | Flows Referencing Object |
|---|---:|
| `Opportunity` | 31 |
| `MessagingSession` | 29 |
| `Lead` | 22 |
| `Group` | 19 |
| `Task` | 15 |
| `Case` | 14 |
| `MessagingEndUser` | 14 |
| `GroupMember` | 13 |
| `User` | 12 |
| `Contact` | 10 |
| `Account` | 9 |
| `RecordType` | 8 |
| `MessagingChannel` | 7 |
| `Consultor__c` | 5 |
| `LeadInteraction__c` | 5 |
| `ViabilityStudy__c` | 4 |
| `EmailTemplate` | 3 |
| `Projeto__c` | 3 |
| `WorkOrder` | 3 |
| `Contract` | 2 |
| `CustomNotificationType` | 2 |
| `Integradores__c` | 2 |
| `PermissionSetLicense` | 2 |
| `PermissionSetLicenseAssign` | 2 |
| `SetupMessagingSession__c` | 2 |
| `ClickSign__c` | 1 |
| `ContentVersion` | 1 |
| `ConversationEntry` | 1 |
| `FeedItem` | 1 |
| `Feedback__c` | 1 |
| `Instalacao__c` | 1 |
| `OpportunityContactRole` | 1 |
| `ServiceAppointment` | 1 |
| `ServicePresenceStatus` | 1 |
| `ServiceTerritory` | 1 |
| `TabelaEzeeConnect__c` | 1 |
| `UserServicePresence` | 1 |
| `WorkType` | 1 |

## Full Relationship Inventory (Lookup/MasterDetail)

| Source Object | Field | Type | Target Object | RelationshipName | Required | File |
|---|---|---|---|---|---|---|
| `Account` | `Consultor__c` | `Lookup` | `Consultor__c` | `Contas` | `false` | `force-app/main/default/objects/Account/fields/Consultor__c.field-meta.xml` |
| `Activity` | `Feedback__c` | `Lookup` | `Feedback__c` | `Activities` | `false` | `force-app/main/default/objects/Activity/fields/Feedback__c.field-meta.xml` |
| `Activity` | `jif6QH2I3t7Mptz__GTM__c` | `Lookup` | `jif6QH2I3t7Mptz__GTM__c` | `Activities` | `false` | `force-app/main/default/objects/Activity/fields/jif6QH2I3t7Mptz__GTM__c.field-meta.xml` |
| `Case` | `Contract__c` | `Lookup` | `Contract` | `Cases` | `false` | `force-app/main/default/objects/Case/fields/Contract__c.field-meta.xml` |
| `Case` | `ManagerName__c` | `Lookup` | `User` | `Casos` | `false` | `force-app/main/default/objects/Case/fields/ManagerName__c.field-meta.xml` |
| `Case` | `Nome_da_Oportunidade__c` | `Lookup` | `Opportunity` | `Casos` | `false` | `force-app/main/default/objects/Case/fields/Nome_da_Oportunidade__c.field-meta.xml` |
| `Case` | `Nome_do_Consultor__c` | `Lookup` | `Consultor__c` | `Casos` | `false` | `force-app/main/default/objects/Case/fields/Nome_do_Consultor__c.field-meta.xml` |
| `Case` | `Oportunidade_Pai__c` | `Lookup` | `Opportunity` | `OportunidadePaiCasos` | `false` | `force-app/main/default/objects/Case/fields/Oportunidade_Pai__c.field-meta.xml` |
| `ClickSignEnvelope__c` | `Account__c` | `Lookup` | `Account` | `ClickSignEnvelopes` | `false` | `force-app/main/default/objects/ClickSignEnvelope__c/fields/Account__c.field-meta.xml` |
| `ClickSignEnvelope__c` | `Case__c` | `Lookup` | `Case` | `ClickSignEnvelopes` | `false` | `force-app/main/default/objects/ClickSignEnvelope__c/fields/Case__c.field-meta.xml` |
| `ClickSignSigner__c` | `ClickSignEnvelope__c` | `Lookup` | `ClickSignEnvelope__c` | `ClickSignSigners` | `false` | `force-app/main/default/objects/ClickSignSigner__c/fields/ClickSignEnvelope__c.field-meta.xml` |
| `ClickSignSigner__c` | `ClickSignTemplate__c` | `Lookup` | `ClickSignTemplate__c` | `ClickSignSigners` | `false` | `force-app/main/default/objects/ClickSignSigner__c/fields/ClickSignTemplate__c.field-meta.xml` |
| `ClickSignSigner__c` | `ClickSign__c` | `Lookup` | `ClickSign__c` | `ClickSignSigners` | `false` | `force-app/main/default/objects/ClickSignSigner__c/fields/ClickSign__c.field-meta.xml` |
| `ClickSignSigner__c` | `Contact__c` | `Lookup` | `Contact` | `ClickSignSigners` | `false` | `force-app/main/default/objects/ClickSignSigner__c/fields/Contact__c.field-meta.xml` |
| `ClickSignSigner__c` | `User__c` | `Lookup` | `User` | `ClickSignSigners` | `false` | `force-app/main/default/objects/ClickSignSigner__c/fields/User__c.field-meta.xml` |
| `ClickSignTemplate__c` | `ClickSignEnvelope__c` | `Lookup` | `ClickSignEnvelope__c` | `ClickSignTemplates` | `false` | `force-app/main/default/objects/ClickSignTemplate__c/fields/ClickSignEnvelope__c.field-meta.xml` |
| `ClickSign__c` | `ClickSignEnvelope__c` | `Lookup` | `ClickSignEnvelope__c` | `ClickSign` | `false` | `force-app/main/default/objects/ClickSign__c/fields/ClickSignEnvelope__c.field-meta.xml` |
| `ClickSign__c` | `ClickSignTemplate__c` | `Lookup` | `ClickSignTemplate__c` | `ClickSign` | `false` | `force-app/main/default/objects/ClickSign__c/fields/ClickSignTemplate__c.field-meta.xml` |
| `ClickSign__c` | `Opportunity__c` | `Lookup` | `Opportunity` | `ClickSign` | `false` | `force-app/main/default/objects/ClickSign__c/fields/Opportunity__c.field-meta.xml` |
| `Consultor__c` | `Usuario__c` | `Lookup` | `User` | `Consultores` | `false` | `force-app/main/default/objects/Consultor__c/fields/Usuario__c.field-meta.xml` |
| `ContentVersion` | `ClickSignEnvelope__c` | `Lookup` | `ClickSignEnvelope__c` | `ContentVersions` | `false` | `force-app/main/default/objects/ContentVersion/fields/ClickSignEnvelope__c.field-meta.xml` |
| `Faturamento__c` | `Caso__c` | `Lookup` | `Case` | `Faturamentos` | `false` | `force-app/main/default/objects/Faturamento__c/fields/Caso__c.field-meta.xml` |
| `Faturamento__c` | `Cliente__c` | `Lookup` | `Account` | `Faturamentos` | `false` | `force-app/main/default/objects/Faturamento__c/fields/Cliente__c.field-meta.xml` |
| `Faturamento__c` | `Instalacao__c` | `Lookup` | `Instalacao__c` | `Faturamentos` | `false` | `force-app/main/default/objects/Faturamento__c/fields/Instalacao__c.field-meta.xml` |
| `Faturamento__c` | `Oportunidade__c` | `Lookup` | `Opportunity` | `Faturamentos` | `false` | `force-app/main/default/objects/Faturamento__c/fields/Oportunidade__c.field-meta.xml` |
| `Faturamento__c` | `Projeto__c` | `Lookup` | `Projeto__c` | `Faturamentos` | `false` | `force-app/main/default/objects/Faturamento__c/fields/Projeto__c.field-meta.xml` |
| `Feedback__c` | `Consultant__c` | `Lookup` | `User` | `Feedbacks` | `false` | `force-app/main/default/objects/Feedback__c/fields/Consultant__c.field-meta.xml` |
| `Feedback__c` | `Opportunity__c` | `Lookup` | `Opportunity` | `Feedbacks` | `false` | `force-app/main/default/objects/Feedback__c/fields/Opportunity__c.field-meta.xml` |
| `Instalacao__c` | `CasoInstalacao__c` | `Lookup` | `Case` | `Instalacoes` | `false` | `force-app/main/default/objects/Instalacao__c/fields/CasoInstalacao__c.field-meta.xml` |
| `Instalacao__c` | `ClienteConta__c` | `Lookup` | `Account` | `Instalacoes` | `false` | `force-app/main/default/objects/Instalacao__c/fields/ClienteConta__c.field-meta.xml` |
| `Instalacao__c` | `ConsultorInstalacao__c` | `Lookup` | `Consultor__c` | `Instalacoes` | `false` | `force-app/main/default/objects/Instalacao__c/fields/ConsultorInstalacao__c.field-meta.xml` |
| `Instalacao__c` | `GestorObra__c` | `Lookup` | `User` | `InstalacoesGestor` | `false` | `force-app/main/default/objects/Instalacao__c/fields/GestorObra__c.field-meta.xml` |
| `Instalacao__c` | `Integrador__c` | `Lookup` | `Integradores__c` | `InstalacoesIntegrador` | `false` | `force-app/main/default/objects/Instalacao__c/fields/Integrador__c.field-meta.xml` |
| `Instalacao__c` | `OportunidadeConcluida__c` | `Lookup` | `Opportunity` | `Instalacoes` | `false` | `force-app/main/default/objects/Instalacao__c/fields/OportunidadeConcluida__c.field-meta.xml` |
| `Instalacao__c` | `Oportunidade__c` | `Lookup` | `Opportunity` | `InstalacoesOportunidade` | `false` | `force-app/main/default/objects/Instalacao__c/fields/Oportunidade__c.field-meta.xml` |
| `Instalacao__c` | `PrestadorDeServico__c` | `Lookup` | `Account` | `InstalacoesPrestador` | `false` | `force-app/main/default/objects/Instalacao__c/fields/PrestadorDeServico__c.field-meta.xml` |
| `Instalacao__c` | `Projeto__c` | `Lookup` | `Projeto__c` | `Instalacoes` | `false` | `force-app/main/default/objects/Instalacao__c/fields/Projeto__c.field-meta.xml` |
| `Integradores__c` | `Usuario__c` | `Lookup` | `User` | `Integradores` | `false` | `force-app/main/default/objects/Integradores__c/fields/Usuario__c.field-meta.xml` |
| `Kit_Instalacao__c` | `Nome_da_Oportunidade__c` | `MasterDetail` | `Opportunity` | `Kit_Instalacoes` | `(none)` | `force-app/main/default/objects/Kit_Instalacao__c/fields/Nome_da_Oportunidade__c.field-meta.xml` |
| `Lead` | `ConsultorRegional__c` | `Lookup` | `Consultor__c` | `Lead` | `false` | `force-app/main/default/objects/Lead/fields/ConsultorRegional__c.field-meta.xml` |
| `Lead` | `IndicadoPor__c` | `Lookup` | `Consultor__c` | `Leads` | `false` | `force-app/main/default/objects/Lead/fields/IndicadoPor__c.field-meta.xml` |
| `LeadInteraction__c` | `Lead__c` | `Lookup` | `Lead` | `Interacoes_dos_leads` | `false` | `force-app/main/default/objects/LeadInteraction__c/fields/Lead__c.field-meta.xml` |
| `LeadInteraction__c` | `MessagingSession__c` | `Lookup` | `MessagingSession` | `Intera_es_dos_leads` | `false` | `force-app/main/default/objects/LeadInteraction__c/fields/MessagingSession__c.field-meta.xml` |
| `LeadInteraction__c` | `Messaging_User__c` | `Lookup` | `MessagingEndUser` | `Intera_es_dos_leads` | `false` | `force-app/main/default/objects/LeadInteraction__c/fields/Messaging_User__c.field-meta.xml` |
| `Log__c` | `Lab065_LeadRelated__c` | `Lookup` | `Lead` | `Logs` | `false` | `force-app/main/default/objects/Log__c/fields/Lab065_LeadRelated__c.field-meta.xml` |
| `MessagingEndUser` | `AccountId__c` | `Lookup` | `Account` | `MessagingEndUsers2` | `false` | `force-app/main/default/objects/MessagingEndUser/fields/AccountId__c.field-meta.xml` |
| `MessagingEndUser` | `Consultor__c` | `Lookup` | `Consultor__c` | `Usuarios_do_Messaging` | `false` | `force-app/main/default/objects/MessagingEndUser/fields/Consultor__c.field-meta.xml` |
| `MessagingEndUser` | `Integrador__c` | `Lookup` | `Integradores__c` | `Usuarios_do_Messaging` | `false` | `force-app/main/default/objects/MessagingEndUser/fields/Integrador__c.field-meta.xml` |
| `MessagingEndUser` | `Oportunidade__c` | `Lookup` | `Opportunity` | `Usuarios_do_Messaging` | `false` | `force-app/main/default/objects/MessagingEndUser/fields/Oportunidade__c.field-meta.xml` |
| `MessagingSession` | `EndUserAccountId__c` | `Lookup` | `Account` | `MessagingSessions2` | `false` | `force-app/main/default/objects/MessagingSession/fields/EndUserAccountId__c.field-meta.xml` |
| `MessagingSession` | `QueueSupervisor__c` | `Lookup` | `User` | `Messaging_Sessions` | `false` | `force-app/main/default/objects/MessagingSession/fields/QueueSupervisor__c.field-meta.xml` |
| `Opportunity` | `ConsultorOportunidade__c` | `Lookup` | `Consultor__c` | `Oportunidades` | `false` | `force-app/main/default/objects/Opportunity/fields/ConsultorOportunidade__c.field-meta.xml` |
| `Opportunity` | `Contrato_Integrador__c` | `Lookup` | `Contract` | `Opportunities` | `false` | `force-app/main/default/objects/Opportunity/fields/Contrato_Integrador__c.field-meta.xml` |
| `Opportunity` | `Instalacao__c` | `Lookup` | `Instalacao__c` | `Oportunidades` | `false` | `force-app/main/default/objects/Opportunity/fields/Instalacao__c.field-meta.xml` |
| `Opportunity` | `MainViability__c` | `Lookup` | `ViabilityStudy__c` | `Opportunities` | `false` | `force-app/main/default/objects/Opportunity/fields/MainViability__c.field-meta.xml` |
| `Opportunity` | `Parceiro__c` | `Lookup` | `Parceiro__c` | `Oportunidades` | `false` | `force-app/main/default/objects/Opportunity/fields/Parceiro__c.field-meta.xml` |
| `Opportunity` | `ParentOpportunity__c` | `Lookup` | `Opportunity` | `Opportunities` | `false` | `force-app/main/default/objects/Opportunity/fields/ParentOpportunity__c.field-meta.xml` |
| `Opportunity` | `ResponsavelVisita__c` | `Lookup` | `ServiceResource` | `Oportunidades` | `false` | `force-app/main/default/objects/Opportunity/fields/ResponsavelVisita__c.field-meta.xml` |
| `Opportunity` | `ViabilityStudyOwner__c` | `Lookup` | `User` | `Opportunities` | `false` | `force-app/main/default/objects/Opportunity/fields/ViabilityStudyOwner__c.field-meta.xml` |
| `OpportunityAttachmentLink__c` | `CompletedBy__c` | `Lookup` | `User` | `CompletedBy` | `false` | `force-app/main/default/objects/OpportunityAttachmentLink__c/fields/CompletedBy__c.field-meta.xml` |
| `OpportunityAttachmentLink__c` | `OpportunityId__c` | `Lookup` | `Opportunity` | `Anexos_Externo_da_Oportunidade` | `false` | `force-app/main/default/objects/OpportunityAttachmentLink__c/fields/OpportunityId__c.field-meta.xml` |
| `OpportunityLineItem` | `Kit_Instalacao__c` | `Lookup` | `Kit_Instalacao__c` | `Produto_de_oportunidade` | `false` | `force-app/main/default/objects/OpportunityLineItem/fields/Kit_Instalacao__c.field-meta.xml` |
| `Parceiro__c` | `CapaPromocional__c` | `Lookup` | `ProposalCover__c` | `Parceiros1` | `false` | `force-app/main/default/objects/Parceiro__c/fields/CapaPromocional__c.field-meta.xml` |
| `Parceiro__c` | `CapaProposta__c` | `Lookup` | `ProposalCover__c` | `Parceiros` | `false` | `force-app/main/default/objects/Parceiro__c/fields/CapaProposta__c.field-meta.xml` |
| `Parceiro__c` | `OwnerOpportunity__c` | `Lookup` | `User` | `Parceiros` | `false` | `force-app/main/default/objects/Parceiro__c/fields/OwnerOpportunity__c.field-meta.xml` |
| `Projeto__c` | `Consultor__c` | `Lookup` | `Consultor__c` | `Projetos` | `false` | `force-app/main/default/objects/Projeto__c/fields/Consultor__c.field-meta.xml` |
| `Projeto__c` | `Conta__c` | `MasterDetail` | `Account` | `Projetos` | `(none)` | `force-app/main/default/objects/Projeto__c/fields/Conta__c.field-meta.xml` |
| `Projeto__c` | `GestorObra__c` | `Lookup` | `User` | `ProjetosGestor` | `false` | `force-app/main/default/objects/Projeto__c/fields/GestorObra__c.field-meta.xml` |
| `Projeto__c` | `Instalacao__c` | `Lookup` | `Instalacao__c` | `Projetos` | `false` | `force-app/main/default/objects/Projeto__c/fields/Instalacao__c.field-meta.xml` |
| `Projeto__c` | `Oportunidade__c` | `Lookup` | `Opportunity` | `Projetos` | `false` | `force-app/main/default/objects/Projeto__c/fields/Oportunidade__c.field-meta.xml` |
| `Projeto__c` | `Projetista__c` | `Lookup` | `User` | `Projetos` | `false` | `force-app/main/default/objects/Projeto__c/fields/Projetista__c.field-meta.xml` |
| `Projeto__c` | `Viabilidade__c` | `Lookup` | `ViabilityStudy__c` | `ProjetosViabilidade` | `false` | `force-app/main/default/objects/Projeto__c/fields/Viabilidade__c.field-meta.xml` |
| `ProposalPending__c` | `Opportunity__c` | `Lookup` | `Opportunity` | `ProposalPendings` | `true` | `force-app/main/default/objects/ProposalPending__c/fields/Opportunity__c.field-meta.xml` |
| `ResourceAbsence` | `FSL__Scheduling_Policy_Used__c` | `Lookup` | `FSL__Scheduling_Policy__c` | `Resource_Absences` | `false` | `force-app/main/default/objects/ResourceAbsence/fields/FSL__Scheduling_Policy_Used__c.field-meta.xml` |
| `ServiceAppointment` | `FSL__Related_Service__c` | `Lookup` | `ServiceAppointment` | `Service_Appointments` | `false` | `force-app/main/default/objects/ServiceAppointment/fields/FSL__Related_Service__c.field-meta.xml` |
| `ServiceAppointment` | `FSL__Scheduling_Policy_Used__c` | `Lookup` | `FSL__Scheduling_Policy__c` | `Service_Appointments` | `false` | `force-app/main/default/objects/ServiceAppointment/fields/FSL__Scheduling_Policy_Used__c.field-meta.xml` |
| `ServiceAppointment` | `Oportunidade__c` | `Lookup` | `Opportunity` | `CompromissosServico` | `false` | `force-app/main/default/objects/ServiceAppointment/fields/Oportunidade__c.field-meta.xml` |
| `ServiceAppointment` | `ResponsavelVisita__c` | `Lookup` | `ServiceResource` | `Compromissos_de_servicos` | `false` | `force-app/main/default/objects/ServiceAppointment/fields/ResponsavelVisita__c.field-meta.xml` |
| `SetupMessagingSession__c` | `QueueSupervisor__c` | `Lookup` | `User` | `Configura_o_Messaging_Session` | `false` | `force-app/main/default/objects/SetupMessagingSession__c/fields/QueueSupervisor__c.field-meta.xml` |
| `TabelaEzeeConnect__c` | `Parceiro01__c` | `Lookup` | `Parceiro__c` | `Tabelas_Ezee_Connect` | `false` | `force-app/main/default/objects/TabelaEzeeConnect__c/fields/Parceiro01__c.field-meta.xml` |
| `TabelaEzeeConnect__c` | `Parceiro02__c` | `Lookup` | `Parceiro__c` | `Tabelas_Ezee_Connect1` | `false` | `force-app/main/default/objects/TabelaEzeeConnect__c/fields/Parceiro02__c.field-meta.xml` |
| `TabelaEzeeConnect__c` | `Parceiro03__c` | `Lookup` | `Parceiro__c` | `Tabelas_Ezee_Connect2` | `false` | `force-app/main/default/objects/TabelaEzeeConnect__c/fields/Parceiro03__c.field-meta.xml` |
| `ViabilityStudy__c` | `Opportunity__c` | `Lookup` | `Opportunity` | `Estudos_de_Viabilidades` | `false` | `force-app/main/default/objects/ViabilityStudy__c/fields/Opportunity__c.field-meta.xml` |
| `ViabilityStudy__c` | `Owner__c` | `Lookup` | `User` | `Viabilidades` | `false` | `force-app/main/default/objects/ViabilityStudy__c/fields/Owner__c.field-meta.xml` |
| `ViabilityStudy__c` | `ServiceResource__c` | `Lookup` | `ServiceResource` | `Estudos_de_Viabilidades` | `false` | `force-app/main/default/objects/ViabilityStudy__c/fields/ServiceResource__c.field-meta.xml` |
| `WorkOrder` | `Consultor__c` | `Lookup` | `Consultor__c` | `Ordens_de_trabalho` | `false` | `force-app/main/default/objects/WorkOrder/fields/Consultor__c.field-meta.xml` |
| `WorkOrder` | `FSL__VisitingHours__c` | `Lookup` | `OperatingHours` | `Work_Orders` | `false` | `force-app/main/default/objects/WorkOrder/fields/FSL__VisitingHours__c.field-meta.xml` |
| `WorkOrder` | `InstalacaoAssociada__c` | `Lookup` | `Instalacao__c` | `OrdensTrabalho` | `false` | `force-app/main/default/objects/WorkOrder/fields/InstalacaoAssociada__c.field-meta.xml` |
| `WorkOrder` | `Oportunidade__c` | `Lookup` | `Opportunity` | `Ordens_de_trabalho` | `false` | `force-app/main/default/objects/WorkOrder/fields/Oportunidade__c.field-meta.xml` |
| `WorkOrder` | `Projeto__c` | `Lookup` | `Projeto__c` | `Ordens_de_trabalho` | `false` | `force-app/main/default/objects/WorkOrder/fields/Projeto__c.field-meta.xml` |
| `WorkOrder` | `TecnicoResponsavel__c` | `Lookup` | `ServiceResource` | `Ordens_de_trabalho` | `false` | `force-app/main/default/objects/WorkOrder/fields/TecnicoResponsavel__c.field-meta.xml` |
| `WorkOrder` | `ViabilityStudy__c` | `Lookup` | `ViabilityStudy__c` | `Work_Orders` | `false` | `force-app/main/default/objects/WorkOrder/fields/ViabilityStudy__c.field-meta.xml` |
| `WorkOrderLineItem` | `FSL__VisitingHours__c` | `Lookup` | `OperatingHours` | `Work_Order_Line_Items` | `false` | `force-app/main/default/objects/WorkOrderLineItem/fields/FSL__VisitingHours__c.field-meta.xml` |
| `lb065_Project__c` | `AccountId__c` | `Lookup` | `Account` | `Projetos1` | `false` | `force-app/main/default/objects/lb065_Project__c/fields/AccountId__c.field-meta.xml` |
| `lb065_Project__c` | `Contract__c` | `MasterDetail` | `Contract` | `Projetos` | `(none)` | `force-app/main/default/objects/lb065_Project__c/fields/Contract__c.field-meta.xml` |
