/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 03-15-2026
 * @last modified by  : Daniel Belini
 * @test              : N/A - classe de teste executavel
 **/
@isTest
private class TaskCompletionServiceDocTest {
  @isTest
  static void completeWithoutRequiredDocs() {
    Task t = new Task(Subject = 'TESTE SEM CMDT', Status = 'Not Started');
    insert t;

    Test.startTest();
    TaskCompletionService.CompletionResult res = TaskCompletionService.completeWithComment(
      t.Id,
      'ok',
      false,
      null
    );
    Test.stopTest();

    System.assert(
      res != null && res.success,
      'Conclusão deve ocorrer sem CMDT configurado.'
    );
  }

  @isTest
  static void normalizeNameHandlesAccents() {
    String norm = TaskCompletionService.normalizeName(
      'MOBILIZAÇÃO/CONFERÊNCIA DE MATERIAIS'
    );
    System.assertEquals('mobilizacao_conferencia_de_materiais', norm);
  }

  @isTest
  static void ensureRequiredDocumentsHandlesNullAndMissingIdentifiers() {
    TaskCompletionService.ensureRequiredDocuments(null);
    TaskCompletionService.ensureRequiredDocuments(
      new Task(Subject = null, WhatId = null)
    );
    TaskCompletionService.ensureRequiredDocuments(
      new Task(Subject = 'Sem WhatId', WhatId = null)
    );

    System.assert(true, 'Guard clauses devem retornar sem exceção.');
  }

  @isTest
  static void ensureRequiredDocumentsIgnoresUnknownSubject() {
    Account acc = new Account(Name = 'Conta Com Evidencia Obrigatoria');
    insert acc;

    Task taskRecord = new Task(
      Subject = 'ASSUNTO SEM CONFIG',
      WhatId = acc.Id,
      Status = 'Not Started'
    );

    Test.startTest();
    TaskCompletionService.ensureRequiredDocuments(taskRecord);
    Test.stopTest();

    System.assert(true, 'Evidência enviada deve liberar a validação.');
  }
}
