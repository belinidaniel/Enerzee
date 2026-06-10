/**
 * @description Cria o resumo inicial público dos chamados do Help Desk.
 * @test HelpDeskInitialCommentServiceTest
 */
public without sharing class HelpDeskInitialCommentService {
  private static final Integer MAX_COMMENT_LENGTH = 3900;

  public static void createForCase(Id caseId) {
    if (caseId == null) {
      return;
    }

    List<Case> cases = HelpDeskCaseDAO.queryInitialCommentCases(
      new Set<Id>{ caseId }
    );
    if (cases.isEmpty()) {
      return;
    }

    Case caseRecord = cases[0];
    HelpDeskCaseDAO.insertMessage(
      new HelpDeskMessage__c(
        Case__c = caseRecord.Id,
        Body__c = truncate(buildBody(caseRecord), MAX_COMMENT_LENGTH),
        AuthorName__c = 'Salesforce Help Desk',
        AuthorType__c = 'Agente',
        IsPublic__c = true
      )
    );
  }

  @TestVisible
  private static String buildBody(Case caseRecord) {
    Boolean hasContact = caseRecord.ContactId != null;
    String requesterName = hasContact
      ? caseRecord.Contact.Name
      : caseRecord.CreatedBy.Name;
    String requesterEmail = firstNotBlank(
      hasContact ? caseRecord.Contact.Email : caseRecord.CreatedBy.Email,
      caseRecord.SuppliedEmail
    );
    String requesterPhone = firstNotBlank(
      hasContact
        ? firstNotBlank(
            caseRecord.Contact.MobilePhone,
            caseRecord.Contact.Phone
          )
        : firstNotBlank(
            caseRecord.CreatedBy.MobilePhone,
            caseRecord.CreatedBy.Phone
          ),
      caseRecord.SuppliedPhone
    );
    String requesterRole = hasContact
      ? 'Contato'
      : valueOrDefault(caseRecord.CreatedBy.UserRole?.Name);
    String requesterProfile = hasContact
      ? 'Contato vinculado ao Salesforce'
      : valueOrDefault(caseRecord.CreatedBy.Profile?.Name);
    String requesterTitle = hasContact
      ? caseRecord.Contact.Title
      : caseRecord.CreatedBy.Title;
    String requesterAccount = hasContact && caseRecord.Contact.Account != null
      ? caseRecord.Contact.Account.Name
      : caseRecord.Account?.Name;

    String managerName = firstNotBlank(
      caseRecord.Gerente__r?.Name,
      caseRecord.GerenteNome__c
    );
    String description = String.isNotBlank(caseRecord.Description_Rich__c)
      ? caseRecord.Description_Rich__c.stripHtmlTags()
      : caseRecord.Description;
    String caseUrl =
      URL.getOrgDomainUrl().toExternalForm() +
      '/lightning/r/Case/' +
      caseRecord.Id +
      '/view';

    List<String> lines = new List<String>{
      'RESUMO INICIAL DO CHAMADO',
      '',
      'DADOS DO CASO',
      'Número: ' + valueOrDefault(caseRecord.CaseNumber),
      'Assunto: ' + valueOrDefault(caseRecord.Subject),
      'Sistema: ' + valueOrDefault(caseRecord.HelpDesk_Sistema__c),
      'Tipo: ' + valueOrDefault(caseRecord.HelpDesk_Tipo__c),
      'Origem: ' + valueOrDefault(caseRecord.Origin),
      'Status do caso: ' + valueOrDefault(caseRecord.Status),
      'Status da aprovação: ' + valueOrDefault(caseRecord.StatusAprovacao__c),
      'Criado em: ' +
      (caseRecord.CreatedDate == null
        ? 'Não informado'
        : caseRecord.CreatedDate.format('dd/MM/yyyy HH:mm')),
      'Link Salesforce: ' + caseUrl,
      '',
      'SOLICITANTE',
      'Nome: ' + valueOrDefault(requesterName),
      'Tipo de cadastro: ' + (hasContact ? 'Contato' : 'Usuário Salesforce'),
      'Papel Salesforce: ' + valueOrDefault(requesterRole),
      'Perfil Salesforce: ' + valueOrDefault(requesterProfile),
      'Cargo: ' + valueOrDefault(requesterTitle),
      'Conta: ' + valueOrDefault(requesterAccount),
      'Telefone: ' + valueOrDefault(requesterPhone),
      'E-mail: ' + valueOrDefault(requesterEmail),
      'Telefone informado para contato: ' +
      valueOrDefault(caseRecord.SuppliedPhone),
      'E-mail informado para contato: ' +
      valueOrDefault(caseRecord.SuppliedEmail),
      '',
      'GESTOR APROVADOR DESIGNADO',
      'Nome: ' + valueOrDefault(managerName),
      'Papel Salesforce: ' +
      valueOrDefault(caseRecord.Gerente__r?.UserRole?.Name),
      'Perfil Salesforce: ' +
      valueOrDefault(caseRecord.Gerente__r?.Profile?.Name),
      'Cargo: ' + valueOrDefault(caseRecord.Gerente__r?.Title),
      'Telefone: ' +
      valueOrDefault(
        firstNotBlank(
          caseRecord.Gerente__r?.MobilePhone,
          caseRecord.Gerente__r?.Phone
        )
      ),
      'E-mail: ' + valueOrDefault(caseRecord.Gerente__r?.Email),
      '',
      'DESCRIÇÃO INFORMADA',
      valueOrDefault(description)
    };
    return String.join(lines, '\n');
  }

  private static String firstNotBlank(String primary, String fallback) {
    return String.isNotBlank(primary) ? primary : fallback;
  }

  private static String valueOrDefault(String value) {
    return String.isNotBlank(value) ? value.trim() : 'Não informado';
  }

  private static String truncate(String value, Integer maximumLength) {
    if (String.isBlank(value) || value.length() <= maximumLength) {
      return value;
    }
    return value.substring(0, maximumLength - 18) + '\n\n[Texto resumido]';
  }
}
