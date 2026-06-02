/**
 * @description       : Ponte de comentários entre HelpDeskMessage__c (feed do portal Help Desk) e CaseComment (sincronizado com o Jira pelo conector Getint). Quando o cliente/agente adiciona uma mensagem no portal,
 *                       cria um CaseComment correspondente — que o conector envia ao Jira. Anti-loop: só espelha mensagens NATIVAS do portal (ExternalSource__c vazio); mensagens que já vieram de um CaseComment (ponte oposta) são ignoradas.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 06-02-2026
 * @last modified by  : Daniel Belini
 * @test              : HelpDeskMessageBOTest
 **/
public without sharing class HelpDeskMessageBO {
  /**
   * Espelha mensagens novas do portal como CaseComment (para o conector levar ao Jira).
   * Executado no afterInsert do HelpDeskMessageTrigger.
   */
  public static void mirrorToCaseComments(
    List<HelpDeskMessage__c> newMessages
  ) {
    if (newMessages == null || newMessages.isEmpty()) {
      return;
    }

    List<CaseComment> comments = new List<CaseComment>();
    for (HelpDeskMessage__c m : newMessages) {
      // Só espelha mensagens nativas do portal; as que vieram da ponte
      // (ExternalSource__c preenchido) não geram CaseComment de volta.
      if (
        m.Case__c == null ||
        String.isBlank(m.Body__c) ||
        String.isNotBlank(m.ExternalSource__c)
      ) {
        continue;
      }
      comments.add(
        new CaseComment(
          ParentId = m.Case__c,
          CommentBody = m.Body__c,
          IsPublished = m.IsPublic__c == true
        )
      );
    }

    if (comments.isEmpty()) {
      return;
    }

    // Suprime o trigger de CaseComment para não recriar a mensagem no portal.
    Boolean previous = CaseCommentBO.suppressMirrorToMessage;
    CaseCommentBO.suppressMirrorToMessage = true;
    try {
      insert comments;
    } finally {
      CaseCommentBO.suppressMirrorToMessage = previous;
    }
  }
}
