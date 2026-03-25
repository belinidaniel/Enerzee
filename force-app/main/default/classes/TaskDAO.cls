/**
 * @description       : DAO para queries sobre o objeto Task.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-25-2026
 * @last modified by  : Daniel Belini
 * @test              : AdditionalCoverageNewClassesTest, InstalacaoBOTest, OpportunityBOAdditionalTest,
 *                       OpportunityBOCoverageTest, OpportunityBOEmailTest, OpportunityBOHighCoverageTest,
 *                       OpportunityBOIntegrationVOFixesTest, OpportunityBOPaymentConfirmationTaskTest,
 *                       OpportunityBOPaymentReminderTaskTest, OpportunityDisqualifyLeadsTest, OpportunityTriggerTest,
 *                       PDFControllerExtensionExtraTest
 **/
public with sharing class TaskDAO {
  /**
   * Retorna o Set de oppIds que já possuem pelo menos uma Task aberta
   * com o assunto exato fornecido. Usado para dedup antes de criar tasks.
   */
  public static Set<Id> findOppsWithOpenTaskBySubject(
    Set<Id> oppIds,
    String subject
  ) {
    Set<Id> result = new Set<Id>();
    if (oppIds.isEmpty()) {
      return result;
    }
    for (Task t : [
      SELECT WhatId
      FROM Task
      WHERE
        WhatId IN :oppIds
        AND Subject = :subject
        AND Status != :TaskUtils.STATUS_CONCLUIDO
        AND IsDeleted = FALSE
    ]) {
      result.add(t.WhatId);
    }
    return result;
  }

  /**
   * Retorna List<Task> com tasks abertas para os WhatIds fornecidos.
   * Campos: Id, Status, Description, OwnerId, WhatId.
   * Usado em closeTasksForOpportunityIds e closeViabilityTasks para fechar tasks em bulk.
   */
  public static List<Task> findOpenTasksByWhatIds(Set<Id> whatIds) {
    if (whatIds == null || whatIds.isEmpty()) {
      return new List<Task>();
    }
    return [
      SELECT Id, Status, Description, OwnerId, WhatId
      FROM Task
      WHERE WhatId IN :whatIds AND Status != :TaskUtils.STATUS_CONCLUIDO
    ];
  }

  /**
   * Retorna Map<oppId, Set<assunto normalizado (lowercase/trim)>> de tasks abertas.
   * Usado para dedup multi-assunto em createRequiredFieldsReminderTasks.
   * O Map é inicializado com todos os oppIds fornecidos (Set vazio por default).
   */
  public static Map<Id, Set<String>> findOpenTaskNormalizedSubjectsByOpp(
    Set<Id> oppIds
  ) {
    Map<Id, Set<String>> result = new Map<Id, Set<String>>();
    for (Id oppId : oppIds) {
      result.put(oppId, new Set<String>());
    }
    if (oppIds.isEmpty()) {
      return result;
    }
    for (Task t : [
      SELECT WhatId, Subject
      FROM Task
      WHERE
        WhatId IN :oppIds
        AND IsDeleted = FALSE
        AND Status != :TaskUtils.STATUS_CONCLUIDO
    ]) {
      String norm = t.Subject == null ? '' : t.Subject.trim().toLowerCase();
      result.get(t.WhatId).add(norm);
    }
    return result;
  }
}
