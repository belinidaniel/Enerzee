/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-20-2026
 * @last modified by  : Daniel Belini
 * @test              : InstalacaoBOTest, InstalacaoTriggerHandlerTest, ProjetoTriggerTest
 **/
public with sharing class InstalacaoBO {
  private static final Integer INSTALLATION_NAME_MAX_LENGTH = Schema.SObjectType.Instalacao__c.fields.Name.getLength();

  /**
   * SAL-401: Cria Instalacao__c para todos os projetos recém-criados, independente da categoria.
   * Idempotente: ignora projetos que já possuem Instalacao__c vinculada.
   */
  public static void createInstallationsOnProjectCreation(
    List<Projeto__c> projects
  ) {
    if (projects == null || projects.isEmpty()) {
      return;
    }

    Set<Id> projectIds = new Set<Id>();
    for (Projeto__c project : projects) {
      projectIds.add(project.Id);
    }

    Map<Id, Instalacao__c> existingByProject = new Map<Id, Instalacao__c>();
    for (Instalacao__c inst : [
      SELECT Id, Projeto__c
      FROM Instalacao__c
      WHERE Projeto__c IN :projectIds
    ]) {
      existingByProject.put(inst.Projeto__c, inst);
    }

    // REQ-001: busca dados da Oportunidade para popular relacionamentos da Instalação na criação
    Set<Id> oppIds = new Set<Id>();
    for (Projeto__c p : projects) {
      if (p.Oportunidade__c != null) {
        oppIds.add(p.Oportunidade__c);
      }
    }
    Map<Id, Opportunity> oppById = new Map<Id, Opportunity>();
    if (!oppIds.isEmpty()) {
      for (Opportunity opp : [
        SELECT Id, AccountId, ConsultorOportunidade__c
        FROM Opportunity
        WHERE Id IN :oppIds
        WITH SECURITY_ENFORCED
      ]) {
        oppById.put(opp.Id, opp);
      }
    }

    List<Instalacao__c> toInsert = new List<Instalacao__c>();
    for (Projeto__c project : projects) {
      if (
        project.Instalacao__c != null ||
        existingByProject.containsKey(project.Id)
      ) {
        continue;
      }
      toInsert.add(buildInstallation(project, oppById));
    }

    if (toInsert.isEmpty()) {
      return;
    }

    insert toInsert;
    relateProjectsToInstallations(projects, toInsert);
  }

  /**
   * SAL-402: Bloqueia a transição para "Obra Concluída" se campos obrigatórios
   * dos FieldSets com IsSectionRequired__c = true não estiverem preenchidos.
   * Deve ser chamado em beforeUpdate da Instalacao__c.
   */
  public static void validateRequiredFieldsOnObraConluida(
    List<Instalacao__c> newRecordList,
    Map<Id, Instalacao__c> oldMap
  ) {
    if (newRecordList == null || newRecordList.isEmpty()) {
      return;
    }

    List<Instalacao__c> toValidate = new List<Instalacao__c>();
    for (Instalacao__c inst : newRecordList) {
      Instalacao__c oldInst = oldMap != null ? oldMap.get(inst.Id) : null;
      if (oldInst == null || inst.Status__c == oldInst.Status__c) {
        continue;
      }
      if (
        isObraConcluida(inst.Status__c) && !isObraConcluida(oldInst.Status__c)
      ) {
        toValidate.add(inst);
      }
    }

    if (toValidate.isEmpty()) {
      return;
    }

    // Load required field set names from Custom Metadata (CMDT query — cheap)
    List<FieldSetMapping__mdt> requiredMappings = [
      SELECT FieldSetName__c, SectionLabel__c, Subject__c
      FROM FieldSetMapping__mdt
      WHERE ObjectApiName__c = 'Instalacao__c' AND IsSectionRequired__c = TRUE
    ];

    if (requiredMappings.isEmpty()) {
      return;
    }

    // Collect subjects that require a linked Task to exist before validating
    Set<String> subjectsRequiringTask = new Set<String>();
    for (FieldSetMapping__mdt mapping : requiredMappings) {
      if (String.isNotBlank(mapping.Subject__c)) {
        subjectsRequiringTask.add(mapping.Subject__c.trim().toLowerCase());
      }
    }

    // Query once for all installations: which task subjects actually exist
    Set<Id> instIds = new Set<Id>();
    for (Instalacao__c inst : toValidate) {
      instIds.add(inst.Id);
    }
    Map<Id, Set<String>> existingSubjectsByInst = new Map<Id, Set<String>>();
    if (!subjectsRequiringTask.isEmpty()) {
      for (Task t : [
        SELECT WhatId, Subject
        FROM Task
        WHERE WhatId IN :instIds AND IsDeleted = FALSE
      ]) {
        if (!existingSubjectsByInst.containsKey(t.WhatId)) {
          existingSubjectsByInst.put(t.WhatId, new Set<String>());
        }
        if (String.isNotBlank(t.Subject)) {
          existingSubjectsByInst.get(t.WhatId)
            .add(t.Subject.trim().toLowerCase());
        }
      }
    }

    // Resolve updateable fields from each required FieldSet via Schema API (no SOQL)
    Map<String, Schema.FieldSet> fieldSetMap = Schema.SObjectType.Instalacao__c.fieldSets.getMap();
    // fieldApiName → section label for user-friendly error messages
    // fieldApiName → required subject (null = always required)
    Map<String, String> requiredFieldToSection = new Map<String, String>();
    Map<String, String> requiredFieldToSubject = new Map<String, String>();

    for (FieldSetMapping__mdt mapping : requiredMappings) {
      if (String.isBlank(mapping.FieldSetName__c)) {
        continue;
      }

      Schema.FieldSet fs = resolveFieldSet(
        fieldSetMap,
        mapping.FieldSetName__c
      );
      if (fs == null) {
        continue;
      }

      String sectionLabel = String.isNotBlank(mapping.SectionLabel__c)
        ? mapping.SectionLabel__c
        : mapping.FieldSetName__c;

      String subjectKey = String.isNotBlank(mapping.Subject__c)
        ? mapping.Subject__c.trim().toLowerCase()
        : null;

      for (Schema.FieldSetMember member : fs.getFields()) {
        if (member.getSObjectField().getDescribe().isUpdateable()) {
          requiredFieldToSection.put(member.getFieldPath(), sectionLabel);
          requiredFieldToSubject.put(member.getFieldPath(), subjectKey);
        }
      }
    }

    if (requiredFieldToSection.isEmpty()) {
      return;
    }

    Map<String, Schema.SObjectField> fieldMap = Schema.SObjectType.Instalacao__c.fields.getMap();

    for (Instalacao__c inst : toValidate) {
      Set<String> presentSubjects = existingSubjectsByInst.containsKey(inst.Id)
        ? existingSubjectsByInst.get(inst.Id)
        : new Set<String>();

      List<String> missingLabels = new List<String>();
      for (String fieldApiName : requiredFieldToSection.keySet()) {
        String subjectKey = requiredFieldToSubject.get(fieldApiName);
        // Se o fieldset exige que exista uma Task com determinado Subject e ela não existe, ignora
        if (subjectKey != null && !presentSubjects.contains(subjectKey)) {
          continue;
        }
        Object value = inst.get(fieldApiName);
        Boolean isEmpty = value == null || String.valueOf(value).trim() == '';
        if (isEmpty) {
          Schema.SObjectField sField = fieldMap.get(fieldApiName);
          String label = sField != null
            ? sField.getDescribe().getLabel()
            : fieldApiName;
          missingLabels.add(
            label + ' (' + requiredFieldToSection.get(fieldApiName) + ')'
          );
        }
      }
      if (!missingLabels.isEmpty()) {
        inst.addError(
          'Para avançar para Obra Concluída, preencha os seguintes campos obrigatórios: ' +
          String.join(missingLabels, ', ')
        );
      }
    }
  }

  private static Boolean isObraConcluida(String status) {
    if (String.isBlank(status)) {
      return false;
    }
    return status.equalsIgnoreCase(ProjetoUtils.STATUS_OBRA_CONCLUIDA) ||
      status.equalsIgnoreCase(
        ProjetoUtils.STATUS_OBRA_CONCLUIDA_AGUARDANDO_TROCA_DE_MEDIDOR
      );
  }

  private static Schema.FieldSet resolveFieldSet(
    Map<String, Schema.FieldSet> fieldSetMap,
    String fieldSetName
  ) {
    if (fieldSetMap == null || String.isBlank(fieldSetName)) {
      return null;
    }
    Schema.FieldSet fs = fieldSetMap.get(fieldSetName);
    if (fs != null) {
      return fs;
    }
    // Case-insensitive fallback
    for (String key : fieldSetMap.keySet()) {
      if (key.equalsIgnoreCase(fieldSetName)) {
        return fieldSetMap.get(key);
      }
    }
    return null;
  }

  public static void createInstallationsForFastTrackProjects(
    List<Projeto__c> projects,
    Map<Id, Opportunity> opportunityById
  ) {
    if (projects == null || projects.isEmpty()) {
      return;
    }

    List<Projeto__c> fastTrackProjects = new List<Projeto__c>();
    Set<Id> projectIds = new Set<Id>();

    for (Projeto__c project : projects) {
      Opportunity opp = opportunityById != null
        ? opportunityById.get(project.Oportunidade__c)
        : null;
      if (
        opp != null &&
        opp.Categoria__c != null &&
        opp.Categoria__c.equalsIgnoreCase('Fast Track')
      ) {
        fastTrackProjects.add(project);
        projectIds.add(project.Id);
      }
    }

    if (fastTrackProjects.isEmpty()) {
      return;
    }

    Map<Id, Instalacao__c> existingByProject = new Map<Id, Instalacao__c>();
    for (Instalacao__c inst : [
      SELECT Id, Projeto__c
      FROM Instalacao__c
      WHERE Projeto__c IN :projectIds
    ]) {
      existingByProject.put(inst.Projeto__c, inst);
    }

    List<Instalacao__c> toInsert = new List<Instalacao__c>();
    for (Projeto__c project : fastTrackProjects) {
      if (
        project.Instalacao__c != null ||
        existingByProject.containsKey(project.Id)
      ) {
        continue;
      }
      // REQ-001: passa opportunityById para popular ConsultorInstalacao__c
      toInsert.add(buildInstallation(project, opportunityById));
    }
    System.debug(
      '### InstalacaoBO.createInstallationsForFastTrackProjects - toInsert: ' +
      toInsert
    );
    if (toInsert.isEmpty()) {
      return;
    }

    insert toInsert;
    relateProjectsToInstallations(fastTrackProjects, toInsert);
  }

  /**
   * REQ-001: Sincroniza ConsultorInstalacao__c e ClienteConta__c nas Instalações
   * vinculadas quando ConsultorOportunidade__c ou AccountId mudam na Oportunidade.
   * Chamado em afterUpdate do trigger de Opportunity. Bulk-safe: uma SOQL + um DML
   * para qualquer volume.
   */
  public static void syncConsultorFromOpportunity(
    List<Opportunity> newList,
    Map<Id, Opportunity> oldMap
  ) {
    if (newList == null || newList.isEmpty()) {
      return;
    }

    Map<Id, Opportunity> changedOppById = new Map<Id, Opportunity>();
    for (Opportunity opp : newList) {
      Opportunity oldOpp = oldMap != null ? oldMap.get(opp.Id) : null;
      Boolean consultorChanged =
        oldOpp == null ||
        opp.ConsultorOportunidade__c != oldOpp.ConsultorOportunidade__c;
      Boolean accountChanged =
        oldOpp == null ||
        opp.AccountId != oldOpp.AccountId;
      if (consultorChanged || accountChanged) {
        changedOppById.put(opp.Id, opp);
      }
    }

    if (changedOppById.isEmpty()) {
      return;
    }

    Set<Id> changedOppIds = changedOppById.keySet();

    // Busca Instalações vinculadas pelos dois campos de lookup possíveis
    List<Instalacao__c> linkedInstalacoes = [
      SELECT
        Id,
        ClienteConta__c,
        ConsultorInstalacao__c,
        Oportunidade__c,
        OportunidadeConcluida__c
      FROM Instalacao__c
      WHERE
        Oportunidade__c IN :changedOppIds
        OR OportunidadeConcluida__c IN :changedOppIds
      WITH SECURITY_ENFORCED
    ];

    if (linkedInstalacoes.isEmpty()) {
      return;
    }

    List<Instalacao__c> toUpdate = new List<Instalacao__c>();
    for (Instalacao__c inst : linkedInstalacoes) {
      // Prioriza Oportunidade__c; fallback para OportunidadeConcluida__c
      Id refOppId = inst.Oportunidade__c != null
        ? inst.Oportunidade__c
        : inst.OportunidadeConcluida__c;

      if (!changedOppById.containsKey(refOppId)) {
        continue;
      }

      Opportunity changedOpp = changedOppById.get(refOppId);
      Id newConsultorId = changedOpp.ConsultorOportunidade__c;
      Id newClientId = changedOpp.AccountId;

      Instalacao__c updateInst = new Instalacao__c(Id = inst.Id);
      Boolean hasChanges = false;

      if (inst.ConsultorInstalacao__c != newConsultorId) {
        updateInst.ConsultorInstalacao__c = newConsultorId;
        hasChanges = true;
      }
      if (inst.ClienteConta__c != newClientId) {
        updateInst.ClienteConta__c = newClientId;
        hasChanges = true;
      }

      if (hasChanges) {
        toUpdate.add(updateInst);
      }
    }

    if (toUpdate.isEmpty()) {
      return;
    }

    // Desabilita o trigger de Instalação para evitar recursão desnecessária
    InstalacaoTriggerHandler.disableTrigger();
    try {
      update toUpdate;
    } finally {
      InstalacaoTriggerHandler.enableTrigger();
    }
  }

  public static void checkTasksConclusionBeforeStatusChange(
    List<Instalacao__c> newRecordList,
    Map<Id, Instalacao__c> oldMap
  ) {
    System.debug(
      '### InstalacaoBO.checkTasksConclusionBeforeStatusChange - newRecordList: ' +
      newRecordList
    );
    if (newRecordList == null || newRecordList.isEmpty()) {
      return;
    }
    System.debug(
      '### InstalacaoBO.checkTasksConclusionBeforeStatusChange - Start'
    );
    for (Instalacao__c inst : newRecordList) {
      System.debug(
        '### InstalacaoBO.checkTasksConclusionBeforeStatusChange - looping inst: ' +
        inst
      );
      Instalacao__c oldInst = oldMap != null ? oldMap.get(inst.Id) : null;
      if (oldInst == null || inst.Status__c == oldInst.Status__c) {
        continue;
      }

      if (TaskBO.hasOpenTasks(inst.Id)) {
        inst.addError(
          'Todas as tarefas existentes para esta instalação precisam estar concluídas antes de avançar de fase.'
        );
      }
    }
  }

  public static void ensureInstallationOnProjectApproved(
    List<Projeto__c> newProjects,
    Map<Id, Projeto__c> oldMap
  ) {
    if (newProjects == null || newProjects.isEmpty()) {
      return;
    }

    List<Projeto__c> toProcess = new List<Projeto__c>();
    Set<Id> projectIds = new Set<Id>();
    Set<Id> opportunityIdsToAdvance = new Set<Id>();

    for (Projeto__c project : newProjects) {
      Projeto__c oldProject = oldMap != null ? oldMap.get(project.Id) : null;

      Boolean statusApproved =
        project.Status__c != null &&
        project.Status__c.equalsIgnoreCase(
          ProjetoUtils.STATUS_PROJETO_APROVADO
        ) &&
        (oldProject == null ||
        !project.Status__c.equalsIgnoreCase(oldProject.Status__c));

      Boolean approvalDateFilled =
        project.ApprovalDate__c != null &&
        (oldProject == null ||
        project.ApprovalDate__c != oldProject.ApprovalDate__c);

      Boolean movedToApproved = statusApproved || approvalDateFilled;

      if (movedToApproved) {
        if (project.Oportunidade__c != null) {
          opportunityIdsToAdvance.add(project.Oportunidade__c);
        }
        if (project.Instalacao__c == null) {
          toProcess.add(project);
          projectIds.add(project.Id);
        }
      }
    }

    advanceOpportunitiesToPaymentConfirmation(opportunityIdsToAdvance);

    if (toProcess.isEmpty()) {
      return;
    }

    Map<Id, Instalacao__c> existingByProject = new Map<Id, Instalacao__c>();
    for (Instalacao__c inst : [
      SELECT Id, Projeto__c
      FROM Instalacao__c
      WHERE Projeto__c IN :projectIds
    ]) {
      existingByProject.put(inst.Projeto__c, inst);
    }

    // REQ-001: busca dados da Oportunidade para popular relacionamentos da Instalação na aprovação
    Set<Id> approvalOppIds = new Set<Id>();
    for (Projeto__c p : toProcess) {
      if (p.Oportunidade__c != null) {
        approvalOppIds.add(p.Oportunidade__c);
      }
    }
    Map<Id, Opportunity> approvalOppById = new Map<Id, Opportunity>();
    if (!approvalOppIds.isEmpty()) {
      for (Opportunity opp : [
        SELECT Id, AccountId, ConsultorOportunidade__c
        FROM Opportunity
        WHERE Id IN :approvalOppIds
        WITH SECURITY_ENFORCED
      ]) {
        approvalOppById.put(opp.Id, opp);
      }
    }

    List<Instalacao__c> toInsert = new List<Instalacao__c>();
    for (Projeto__c project : toProcess) {
      if (existingByProject.containsKey(project.Id)) {
        continue;
      }
      toInsert.add(buildInstallation(project, approvalOppById));
    }

    if (toInsert.isEmpty()) {
      return;
    }

    insert toInsert;
    relateProjectsToInstallations(toProcess, toInsert);
  }

  private static void advanceOpportunitiesToPaymentConfirmation(
    Set<Id> opportunityIds
  ) {
    if (opportunityIds == null || opportunityIds.isEmpty()) {
      return;
    }

    List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
    for (Opportunity opp : [
      SELECT Id, StageName, RecordTypeId, IsClosed
      FROM Opportunity
      WHERE Id IN :opportunityIds AND IsClosed = FALSE // BUG FIX: não regredir Oportunidades já fechadas (ex: "Ganho fechado")
    ]) {
      if (
        opp.StageName != null &&
        opp.StageName.equalsIgnoreCase(
          OpportunityUtils.STATUS_PARECER_DE_ACESSO
        )
      ) {
        String targetStage = OpportunityUtils.resolveStageForProjectCompletion(
          opp
        );
        opportunitiesToUpdate.add(
          new Opportunity(Id = opp.Id, StageName = targetStage)
        );
      }
    }

    if (!opportunitiesToUpdate.isEmpty()) {
      update opportunitiesToUpdate;
    }
  }

  private static Instalacao__c buildInstallation(Projeto__c project) {
    String installationName = buildInstallationName(
      project != null ? project.Name : null
    );

    return new Instalacao__c(
      Name = installationName,
      ClienteConta__c = project.Conta__c,
      Oportunidade__c = project.Oportunidade__c,
      OportunidadeConcluida__c = project.Oportunidade__c,
      Projeto__c = project.Id,
      GestorObra__c = project.GestorObra__c,
      InstallDate__c = project.InstallDate__c,
      DateInspection__c = project.DateInspection__c
    );
  }

  /**
   * REQ-001: Overload que também popula ConsultorInstalacao__c a partir do mapa
   * de Oportunidades. Usado em createInstallationsOnProjectCreation,
   * createInstallationsForFastTrackProjects e ensureInstallationOnProjectApproved.
   */
  private static Instalacao__c buildInstallation(
    Projeto__c project,
    Map<Id, Opportunity> oppById
  ) {
    Instalacao__c inst = buildInstallation(project);
    if (oppById != null && project.Oportunidade__c != null) {
      Opportunity opp = oppById.get(project.Oportunidade__c);
      if (opp != null) {
        if (inst.ClienteConta__c == null) {
          inst.ClienteConta__c = opp.AccountId;
        }
        inst.ConsultorInstalacao__c = opp.ConsultorOportunidade__c;
      }
    }
    return inst;
  }

  private static void relateProjectsToInstallations(
    List<Projeto__c> projects,
    List<Instalacao__c> installations
  ) {
    Map<Id, Id> projectIdToInstallationId = new Map<Id, Id>();
    Map<Id, Id> projectIdToOpportunityId = new Map<Id, Id>();

    for (Instalacao__c installation : installations) {
      if (installation.Projeto__c != null) {
        projectIdToInstallationId.put(installation.Projeto__c, installation.Id);
      }
    }

    for (Projeto__c project : projects) {
      if (project.Oportunidade__c != null) {
        projectIdToOpportunityId.put(project.Id, project.Oportunidade__c);
      }
    }

    if (projectIdToInstallationId.isEmpty()) {
      return;
    }

    List<Projeto__c> projectsToUpdate = new List<Projeto__c>();

    for (Projeto__c project : projects) {
      Id installationId = projectIdToInstallationId.get(project.Id);

      if (installationId != null) {
        projectsToUpdate.add(
          new Projeto__c(Id = project.Id, Instalacao__c = installationId)
        );
      }
    }

    if (!projectsToUpdate.isEmpty()) {
      ProjetoTriggerHandler.disableTrigger();
      try {
        update projectsToUpdate;
      } finally {
        ProjetoTriggerHandler.enableTrigger();
      }
    }

    List<Instalacao__c> installationsToUpdate = new List<Instalacao__c>();
    for (Instalacao__c installation : installations) {
      if (installation.Projeto__c != null) {
        Id oppId = projectIdToOpportunityId.get(installation.Projeto__c);
        Boolean needsOppUpdate =
          oppId != null &&
          oppId != installation.Oportunidade__c;
        if (needsOppUpdate) {
          installationsToUpdate.add(
            new Instalacao__c(
              Id = installation.Id,
              Oportunidade__c = oppId,
              OportunidadeConcluida__c = oppId
            )
          );
        }
      }
    }

    if (!installationsToUpdate.isEmpty()) {
      update installationsToUpdate;
    }
  }

  private static String buildInstallationName(String projectName) {
    String baseName = 'Instalação';
    if (String.isNotBlank(projectName)) {
      baseName += ' - ' + projectName.trim();
    }
    return truncateString(baseName, INSTALLATION_NAME_MAX_LENGTH);
  }

  private static String truncateString(String value, Integer maxLength) {
    if (value == null || maxLength == null || maxLength <= 0) {
      return value;
    }
    return value.length() > maxLength ? value.substring(0, maxLength) : value;
  }
}
