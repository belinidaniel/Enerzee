public with sharing class IntegracaoGeradorPropostas {
  @future(callout=true)
  public static void sendCliente(Set<Id> triggerIds) {
    List<Lead> leadList = [
      SELECT
        Id,
        FirstName,
        LastName,
        Company,
        Email,
        CPFCNPJ__c,
        Phone,
        postalCode,
        state,
        city,
        Bairro__c,
        street,
        Complemento__c,
        ConvertedAccountId
      FROM Lead
      WHERE Id IN :triggerIds
    ];

    for (Lead lead : leadList) {
      ClienteRequest corpoRequisicao = new ClienteRequest();

      corpoRequisicao.userType = lead.CPFCNPJ__c.length() > 11 ? 2 : 1; // 0=adm 1=cpf 2=cnpj
      corpoRequisicao.fullName = lead.FirstName + ' ' + lead.LastName;
      corpoRequisicao.corporateName = lead.Company;
      corpoRequisicao.email = lead.Email;
      corpoRequisicao.document = lead.CPFCNPJ__c;
      corpoRequisicao.cellPhone = lead.Phone;
      corpoRequisicao.zipCode = lead.PostalCode;
      corpoRequisicao.street = lead.Street;
      corpoRequisicao.complement = lead.Complemento__c;
      corpoRequisicao.district = lead.Bairro__c;
      corpoRequisicao.city = lead.City;
      corpoRequisicao.state = lead.State;

      try {
        HttpResponse response = chamadaIntegracao(
          JSON.serialize(corpoRequisicao),
          'Cliente'
        );
        Utils.createLog(
          'IntegracaoGeradorPropostas',
          'sendCliente ' + lead.Id,
          response
        );

        if (response.getBody() != null && response.getBody() != '') {
          Map<String, Object> responseBody = (Map<String, Object>) JSON.deserializeUntyped(
            response.getBody()
          );
          Boolean success = Boolean.valueOf(responseBody.get('success'));
          String IdVirtualOffice = String.valueOf(responseBody.get('data'));

          if (success) {
            System.debug('SUCCESS');
            lead.SucessoIntegracaoNivello__c = true;

            System.enqueueJob(
              new UpdateAccountQueueable(
                lead.ConvertedAccountId,
                IdVirtualOffice
              )
            );
          } else {
            System.debug('ERROR');
            lead.SucessoIntegracaoNivello__c = false;
          }

          lead.StatusBodyIntegracaoNivello__c =
            response.getStatusCode() +
            ' ' +
            response.getBody() +
            ' ' +
            response.getStatus();
        }
      } catch (Exception e) {
        Utils.createLog(
          'IntegracaoGeradorPropostas',
          'sendCliente ' + lead.Id,
          e
        );

        lead.SucessoIntegracaoNivello__c = false;
        lead.StatusBodyIntegracaoNivello__c =
          e.getMessage() +
          ' ' +
          e.getStackTraceString();
      }
    }

    LeadTriggerHandler.disableTrigger();
    update leadList;
    //LeadTriggerHandler.enableTrigger();
  }

  private static HttpResponse chamadaIntegracao(
    String body,
    String endpointName
  ) {
    Integrador__mdt parametrosIntegracao = [
      SELECT Id, URL__c
      FROM Integrador__mdt
      WHERE DeveloperName = :endpointName
      LIMIT 1
    ];

    if (parametrosIntegracao == null) {
      throw new IllegalArgumentException(
        'Endpoint não encontrado para: ' + endpointName
      );
    }

    Http httpObj = new Http();
    HttpRequest request = new HttpRequest();

    request.setEndpoint(parametrosIntegracao.URL__c);
    request.setMethod('POST');
    request.setHeader('Content-Type', 'application/json');
    request.setBody(body);

    return Utils.callIntegrationNivello(request);
  }

  public class ClienteRequest {
    public Integer userType;
    public String fullName;
    public String corporateName;
    public String email;
    public String document;
    public String cellPhone;
    public String zipCode;
    public String street;
    public String complement;
    public String district;
    public String city;
    public String state;
  }

  public class UpdateAccountQueueable implements Queueable {
    private String accountId;
    private String idVirtualOffice;

    public UpdateAccountQueueable(String accountId, String idVirtualOffice) {
      this.accountId = accountId;
      this.idVirtualOffice = idVirtualOffice;
    }

    public void execute(QueueableContext context) {
      if (accountId != null) {
        Account associatedAccount = [
          SELECT Id, Name, IdVirtualOffice__c
          FROM Account
          WHERE Id = :accountId
          LIMIT 1
        ];

        if (associatedAccount != null) {
          associatedAccount.IdVirtualOffice__c = idVirtualOffice;
          update associatedAccount;

          System.debug('Conta atualizada com sucesso: ' + associatedAccount.Id);
        } else {
          System.debug(
            'Nenhuma conta associada foi encontrada para o lead convertido.'
          );
        }
      } else {
        System.debug(
          'Nenhuma conta associada foi encontrada para o lead convertido.'
        );
      }
    }
  }
}
