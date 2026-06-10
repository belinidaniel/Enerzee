/**
 * @description       : Ponte de comentários entre HelpDeskMessage__c (feed do portal Help Desk) e CaseComment (sincronizado com o Jira pelo conector Getint). Quando o cliente/agente adiciona uma mensagem no portal,
 *                       cria um CaseComment correspondente — que o conector envia ao Jira. Anti-loop: só espelha mensagens NATIVAS do portal (ExternalSource__c vazio); mensagens que já vieram de um CaseComment (ponte oposta) são ignoradas.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 06-04-2026
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
    List<HelpDeskMessage__c> mirroredMessages = new List<HelpDeskMessage__c>();
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
      mirroredMessages.add(m);
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

    // Guarda o Id do CaseComment criado na mensagem de origem, para que o
    // upload de anexos consiga dar append das URLs no comentário do Jira.
    List<HelpDeskMessage__c> messagesToUpdate = new List<HelpDeskMessage__c>();
    for (Integer i = 0; i < mirroredMessages.size(); i++) {
      messagesToUpdate.add(
        new HelpDeskMessage__c(
          Id = mirroredMessages[i].Id,
          CaseCommentId__c = String.valueOf(comments[i].Id)
        )
      );
    }
    // O trigger de HelpDeskMessage__c só roda em after insert; este update não
    // o dispara, então não há risco de reentrância.
    if (!messagesToUpdate.isEmpty()) {
      update messagesToUpdate;
    }
  }

  /**
   * Marcador da seção de anexos no corpo do comentário. Permite reescrever a
   * seção a cada novo upload (idempotente), sem duplicar linhas.
   */
  private static final String ATTACHMENTS_MARKER = 'Anexos:';

  /**
   * Mantido para compatibilidade com chamadas existentes. Os nomes e URLs
   * recebidos nunca foram a fonte da verdade; a sincronização sempre consulta
   * todos os AttachmentLink__c vinculados à mensagem.
   */
  public static void appendAttachmentUrlsToComment(
    Id messageId,
    List<String> fileNames,
    List<String> urls
  ) {
    syncMirroredCommentAttachments(messageId);
  }

  /**
   * Reescreve a seção "Anexos:" do CaseComment espelhado da mensagem com TODOS
   * os anexos atuais, em lista numerada, para que cheguem ao Jira (conector Getint).
   * Idempotente: cada upload regrava a seção inteira a partir dos AttachmentLink__c.
   * O texto original da mensagem (acima do marcador) é preservado.
   */
  public static void syncMirroredCommentAttachments(Id messageId) {
    if (messageId == null) {
      return;
    }
    List<HelpDeskMessage__c> messages = [
      SELECT CaseCommentId__c, Body__c
      FROM HelpDeskMessage__c
      WHERE Id = :messageId
      LIMIT 1
    ];
    if (messages.isEmpty() || String.isBlank(messages[0].CaseCommentId__c)) {
      return;
    }
    Id commentId = (Id) messages[0].CaseCommentId__c;

    // Fonte da verdade: todos os anexos vinculados à mensagem (não só o atual).
    List<AttachmentLink__c> links = [
      SELECT FileName__c, AttachmentURL__c
      FROM AttachmentLink__c
      WHERE
        SObjectType__c = 'HelpDeskMessage__c'
        AND SObjectId__c = :String.valueOf(messageId)
      ORDER BY CreatedDate ASC
    ];

    List<String> lines = new List<String>();
    Integer index = 1;
    for (AttachmentLink__c link : links) {
      if (String.isBlank(link.AttachmentURL__c)) {
        continue;
      }
      String name = String.isNotBlank(link.FileName__c)
        ? link.FileName__c
        : 'arquivo';
      lines.add(index + '- ' + name + ': ' + link.AttachmentURL__c);
      index++;
    }

    List<CaseComment> existing = [
      SELECT Id, CommentBody
      FROM CaseComment
      WHERE Id = :commentId
      LIMIT 1
    ];
    if (existing.isEmpty()) {
      return;
    }
    CaseComment comment = existing[0];

    // Texto base = corpo da mensagem original (sem a seção de anexos anterior).
    String baseBody = stripAttachmentsSection(comment.CommentBody);

    if (lines.isEmpty()) {
      comment.CommentBody = baseBody;
    } else if (baseBody.endsWith(':')) {
      // O corpo já é um cabeçalho (ex.: "Evidências:") — os links vêm direto
      // abaixo, sem repetir o marcador "Anexos:".
      comment.CommentBody = baseBody + '\n' + String.join(lines, '\n');
    } else {
      comment.CommentBody =
        baseBody +
        '\n\n' +
        ATTACHMENTS_MARKER +
        '\n' +
        String.join(lines, '\n');
    }

    // O update não dispara o trigger afterInsert de CaseComment, então não há
    // risco de recriar a mensagem no portal (ponte oposta).
    update comment;
  }

  /**
   * Remove a seção de anexos previamente gravada (a partir do marcador "Anexos:"
   * OU da primeira linha de link numerada "N- nome: url"), devolvendo só o texto
   * original da mensagem. Garante idempotência entre uploads sucessivos, tanto
   * para o cabeçalho "Anexos:" quanto para corpos-cabeçalho como "Evidências:".
   */
  private static String stripAttachmentsSection(String body) {
    if (String.isBlank(body)) {
      return '';
    }
    Integer cutIndex = body.indexOf(ATTACHMENTS_MARKER);
    // Primeira linha no padrão "N- ...: http" (link gerado por esta classe).
    Matcher linkMatcher = Pattern.compile('(?m)^\\d+- .*?: https?://')
      .matcher(body);
    if (linkMatcher.find()) {
      Integer linkIndex = linkMatcher.start();
      if (cutIndex == -1 || linkIndex < cutIndex) {
        cutIndex = linkIndex;
      }
    }
    if (cutIndex == -1) {
      return body.trim();
    }
    return body.substring(0, cutIndex).trim();
  }
}