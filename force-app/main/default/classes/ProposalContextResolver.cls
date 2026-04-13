/**
 * @description       :
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 04-10-2026
 * @last modified by  : Daniel Belini
 * @test              : ProposalEngineSupportTest
 **/
public with sharing class ProposalContextResolver {
  public class Context {
    public Opportunity opportunity;
    public ProposalCover__c cover;
    public Boolean isPromotional;
    public String scenario;
    public String paymentType;
    public String coverKey;
  }

  public static Boolean determineIsPromotional(Opportunity opportunityRecord) {
    if (opportunityRecord == null) {
      return false;
    }

    return String.isNotBlank(opportunityRecord.TipoKitPromocional__c);
  }

  public static Context resolve(Id opportunityId, Id coverId) {
    if (opportunityId == null || coverId == null) {
      throw new AuraHandledException(
        'O registro da oportunidade e a capa da proposta sao obrigatorios.'
      );
    }

    Opportunity opportunityRecord = [
      SELECT
        Id,
        Name,
        AccountId,
        Account.Name,
        Numeroproposta__c,
        GrupoTarifario__c,
        StageName,
        RecordTypeId,
        RecordType.Name,
        RecordType.DeveloperName,
        PropostaAlterada__c,
        Parceiro__c,
        Parceiro__r.Name,
        ViabilityStudyFinished__c,
        TipoKitPromocional__c,
        DescricaoBateria__c,
        SelectedSimulation__c,
        SelectedSimulation__r.PaymentType__c,
        isPromotional__c
      FROM Opportunity
      WHERE Id = :opportunityId
      LIMIT 1
    ];

    ProposalCover__c coverRecord = [
      SELECT
        Id,
        Name,
        Template__c,
        TemplateUrl__c,
        IsActive__c,
        IntegrationKey__c,
        isPromotional__c
      FROM ProposalCover__c
      WHERE Id = :coverId
      LIMIT 1
    ];

    if (coverRecord.IsActive__c != true) {
      throw new AuraHandledException(
        'A capa de proposta selecionada esta inativa.'
      );
    }

    Context context = new Context();
    context.opportunity = opportunityRecord;
    context.cover = coverRecord;
    context.coverKey = ProposalCoverRoutingService.resolveCoverKey(coverRecord);
    context.paymentType = opportunityRecord.SelectedSimulation__r != null
      ? opportunityRecord.SelectedSimulation__r.PaymentType__c
      : null;
    context.scenario = opportunityRecord.SelectedSimulation__c != null
      ? ProposalConfigurationService.SCENARIO_PAYMENT_SELECTED
      : ProposalConfigurationService.SCENARIO_INITIAL;
    context.isPromotional = determineIsPromotional(opportunityRecord);

    return context;
  }
}
