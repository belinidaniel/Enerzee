/**
 * @description       : Ponte de comentários entre CaseComment (sincronizado com o Jira pelo conector Getint) e HelpDeskMessage__c (feed do portal Help Desk). Espelha um CaseComment recém-criado como HelpDeskMessage__c,
 *                       para que comentários vindos do Jira apareçam no portal do cliente. Anti-loop: a HelpDeskMessage criada recebe ExternalSource__c = CaseComment.Id; e comentários gerados pela ponte oposta são suprimidos via flag transacional.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 06-02-2026
 * @last modified by  : Daniel Belini
 * @test              : CaseCommentBOTest
 **/
public without sharing class CaseCommentBO {
  // Suprime o espelhamento quando o CaseComment foi criado pela própria ponte
  // (HelpDeskMessage__c -> CaseComment), evitando duplicar a mensagem no portal.
  public static Boolean suppressMirrorToMessage = false;

  /**
   * Espelha CaseComments novos como HelpDeskMessage__c (visíveis no portal).
   * Executado no afterInsert do CaseCommentTrigger.
   */
  public static void mirrorToHelpDeskMessages(List<CaseComment> newComments) {
    if (
      suppressMirrorToMessage ||
      newComments == null ||
      newComments.isEmpty()
    ) {
      return;
    }

    Set<Id> commentIds = new Set<Id>();
    for (CaseComment cc : newComments) {
      if (cc.ParentId != null && String.isNotBlank(cc.CommentBody)) {
        commentIds.add(cc.Id);
      }
    }
    if (commentIds.isEmpty()) {
      return;
    }

    // Idempotência: não recria mensagens para comentários já espelhados.
    Set<String> alreadyMirrored = new Set<String>();
    for (HelpDeskMessage__c m : [
      SELECT ExternalSource__c
      FROM HelpDeskMessage__c
      WHERE ExternalSource__c IN :toStringSet(commentIds)
    ]) {
      alreadyMirrored.add(m.ExternalSource__c);
    }

    List<HelpDeskMessage__c> messages = new List<HelpDeskMessage__c>();
    for (CaseComment cc : newComments) {
      if (
        cc.ParentId == null ||
        String.isBlank(cc.CommentBody) ||
        alreadyMirrored.contains(String.valueOf(cc.Id))
      ) {
        continue;
      }
      messages.add(
        new HelpDeskMessage__c(
          Case__c = cc.ParentId,
          Body__c = cc.CommentBody,
          AuthorType__c = 'Agente',
          IsPublic__c = cc.IsPublished == true,
          ExternalSource__c = String.valueOf(cc.Id)
        )
      );
    }

    if (!messages.isEmpty()) {
      insert messages;
    }
  }

  private static Set<String> toStringSet(Set<Id> ids) {
    Set<String> result = new Set<String>();
    for (Id i : ids) {
      result.add(String.valueOf(i));
    }
    return result;
  }
}
