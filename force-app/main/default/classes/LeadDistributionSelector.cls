/**
 * @description       : Seleciona o consultor correto para um Lead e atualiza o "ultimo lead recebido" com lock de linha para evitar concorrencia.
 * @author            : Daniel Belini
 * @group             :
 * @last modified on  : 06-08-2026
 * @last modified by  : Daniel Belini
 * @test              : LeadDistributionSelectorTest
 **/
public with sharing class LeadDistributionSelector {
  private static final Integer LOCK_BATCH_SIZE = 5;
  private static final Set<String> ADVANCED_GRADUATIONS = new Set<String>{
    'Advanced Builder'
  };
  private static final Set<String> HOT_GRADUATIONS = new Set<String>{
    'Gold',
    'Platinum'
  };
  private static final Set<String> PRIORITY_GRADUATIONS = new Set<String>{
    'Diamond',
    'Carbon Diamond'
  };
  private static final Map<String, List<Set<String>>> GRADUATION_LADDER_BY_RATING = new Map<String, List<Set<String>>>{
    'Cold' => new List<Set<String>>{
      ADVANCED_GRADUATIONS,
      HOT_GRADUATIONS,
      PRIORITY_GRADUATIONS
    },
    'Warm' => new List<Set<String>>{
      ADVANCED_GRADUATIONS,
      HOT_GRADUATIONS,
      PRIORITY_GRADUATIONS
    },
    'Hot' => new List<Set<String>>{ HOT_GRADUATIONS, PRIORITY_GRADUATIONS },
    'Prioritário' => new List<Set<String>>{ PRIORITY_GRADUATIONS }
  };

  public class Request {
    @InvocableVariable(required=true)
    public Id leadId;
  }

  public class Response {
    @InvocableVariable
    public Id consultantId;

    @InvocableVariable
    public String message;
  }

  @InvocableMethod(
    label='Select Consultant For Lead (Locked)'
    description='Seleciona o consultor para o Lead e atualiza o último lead recebido usando lock de linha.'
  )
  public static List<Response> selectConsultant(List<Request> requests) {
    List<Response> results = new List<Response>();
    if (requests == null || requests.isEmpty()) {
      return results;
    }

    Set<Id> leadIds = new Set<Id>();
    for (Request req : requests) {
      if (req != null && req.leadId != null) {
        leadIds.add(req.leadId);
      }
    }

    Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
    Boolean hasDistributionType = leadFields.containsKey('Distributiontype__c');
    Boolean hasDistributionValue = leadFields.containsKey(
      'DistributionValue__c'
    );
    Boolean hasConsultorRegional = leadFields.containsKey(
      'ConsultorRegional__c'
    );

    Map<Id, Lead> leadMap = new Map<Id, Lead>();
    if (!leadIds.isEmpty()) {
      List<String> selectFields = new List<String>{ 'Id', 'State', 'Rating' };
      if (hasDistributionType) {
        selectFields.add('Distributiontype__c');
      }
      if (hasDistributionValue) {
        selectFields.add('DistributionValue__c');
      }
      if (hasConsultorRegional) {
        selectFields.add('ConsultorRegional__c');
      }

      String soql =
        'SELECT ' +
        String.join(selectFields, ',') +
        ' FROM Lead WHERE Id IN :leadIds';
      List<Lead> leads = (List<Lead>) Database.query(soql);
      leadMap = new Map<Id, Lead>(leads);
    }

    for (Request req : requests) {
      Response res = new Response();
      Lead lead = req != null ? leadMap.get(req.leadId) : null;
      if (lead == null) {
        res.message = 'Lead nao encontrado.';
        results.add(res);
        continue;
      }

      try {
        res.consultantId = selectConsultantForLead(
          lead,
          hasDistributionType,
          hasDistributionValue,
          hasConsultorRegional
        );
      } catch (Exception ex) {
        res.message = ex.getMessage();
      }

      results.add(res);
    }

    return results;
  }

  private static Id selectConsultantForLead(
    Lead lead,
    Boolean hasDistributionType,
    Boolean hasDistributionValue,
    Boolean hasConsultorRegional
  ) {
    if (lead == null) {
      return null;
    }

    String distributionType = hasDistributionType
      ? (String) lead.get('Distributiontype__c')
      : null;
    String distributionValue = hasDistributionValue
      ? (String) lead.get('DistributionValue__c')
      : null;
    Id consultorRegionalId = hasConsultorRegional
      ? (Id) lead.get('ConsultorRegional__c')
      : null;

    if (
      String.isBlank(lead.State) ||
      !GRADUATION_LADDER_BY_RATING.containsKey(lead.Rating)
    ) {
      return null;
    }

    if (distributionType == 'Email') {
      Id selectedId = selectByEmail(distributionValue, lead.State, lead.Rating);
      if (selectedId != null) {
        return selectedId;
      }
    } else if (distributionType == 'Graduação') {
      Id selectedId = selectByGraduation(
        distributionValue,
        lead.State,
        lead.Rating
      );
      if (selectedId != null) {
        return selectedId;
      }
    }

    return selectByState(lead.State, lead.Rating, consultorRegionalId);
  }

  private static Id selectByEmail(
    String distributionValue,
    String leadState,
    String rating
  ) {
    List<String> emails = splitCsv(distributionValue);
    Set<String> graduations = getPrimaryGraduations(rating);
    if (
      emails.isEmpty() ||
      String.isBlank(leadState) ||
      graduations == null ||
      graduations.isEmpty()
    ) {
      return null;
    }

    List<Consultor__c> candidates = [
      SELECT Id, Lb065_UltimoLeadRecebido__c
      FROM Consultor__c
      WHERE
        Email__c IN :emails
        AND EstadosAtendidos__c INCLUDES (:leadState)
        AND Ativo__c = TRUE
        AND SendLead__c = TRUE
        AND FreezeConsult__c = FALSE
        AND (Lb65_Graduacao__c IN :graduations
        OR SpecialRange__c = :rating)
      ORDER BY Lb065_UltimoLeadRecebido__c ASC
      LIMIT :LOCK_BATCH_SIZE
    ];

    return lockAndUpdate(candidates);
  }

  private static Id selectByGraduation(
    String distributionValue,
    String leadState,
    String rating
  ) {
    List<String> requestedGraduations = splitCsv(distributionValue);
    Set<String> eligibleGraduations = getPrimaryGraduations(rating);
    if (
      requestedGraduations.isEmpty() ||
      String.isBlank(leadState) ||
      eligibleGraduations == null ||
      eligibleGraduations.isEmpty()
    ) {
      return null;
    }

    List<Consultor__c> candidates = [
      SELECT Id, Lb065_UltimoLeadRecebido__c
      FROM Consultor__c
      WHERE
        Lb65_Graduacao__c IN :requestedGraduations
        AND EstadosAtendidos__c INCLUDES (:leadState)
        AND Ativo__c = TRUE
        AND SendLead__c = TRUE
        AND FreezeConsult__c = FALSE
        AND (Lb65_Graduacao__c IN :eligibleGraduations
        OR SpecialRange__c = :rating)
      ORDER BY Lb065_UltimoLeadRecebido__c ASC
      LIMIT :LOCK_BATCH_SIZE
    ];

    return lockAndUpdate(candidates);
  }

  private static Id selectByState(
    String leadState,
    String rating,
    Id consultorRegionalId
  ) {
    List<Set<String>> graduationLadder = GRADUATION_LADDER_BY_RATING.get(
      rating
    );
    if (
      String.isBlank(leadState) ||
      graduationLadder == null ||
      graduationLadder.isEmpty()
    ) {
      return null;
    }

    for (Set<String> graduations : graduationLadder) {
      Id selectedId = selectByStateAndGraduations(
        leadState,
        rating,
        consultorRegionalId,
        graduations
      );
      if (selectedId != null) {
        return selectedId;
      }
    }

    return null;
  }

  private static Id selectByStateAndGraduations(
    String leadState,
    String rating,
    Id consultorRegionalId,
    Set<String> graduations
  ) {
    List<Consultor__c> candidates = [
      SELECT Id, Lb065_UltimoLeadRecebido__c
      FROM Consultor__c
      WHERE
        EstadosAtendidos__c INCLUDES (:leadState)
        AND Ativo__c = TRUE
        AND SendLead__c = TRUE
        AND FreezeConsult__c = FALSE
        AND Id != :consultorRegionalId
        AND (Lb65_Graduacao__c IN :graduations
        OR SpecialRange__c = :rating)
      ORDER BY Lb065_UltimoLeadRecebido__c ASC
      LIMIT :LOCK_BATCH_SIZE
    ];

    return lockAndUpdate(candidates);
  }

  private static Set<String> getPrimaryGraduations(String rating) {
    List<Set<String>> graduationLadder = GRADUATION_LADDER_BY_RATING.get(
      rating
    );
    return graduationLadder == null || graduationLadder.isEmpty()
      ? null
      : graduationLadder[0];
  }

  private static Id lockAndUpdate(List<Consultor__c> candidates) {
    if (candidates == null || candidates.isEmpty()) {
      return null;
    }

    Set<Id> candidateIds = new Set<Id>();
    for (Consultor__c candidate : candidates) {
      if (candidate != null && candidate.Id != null) {
        candidateIds.add(candidate.Id);
      }
    }
    if (candidateIds.isEmpty()) {
      return null;
    }

    List<Consultor__c> locked = [
      SELECT Id, Lb065_UltimoLeadRecebido__c
      FROM Consultor__c
      WHERE Id IN :candidateIds
      FOR UPDATE
    ];

    Consultor__c chosen = chooseOldest(locked);
    if (chosen == null) {
      return null;
    }

    chosen.Lb065_UltimoLeadRecebido__c = System.now();
    update chosen;
    return chosen.Id;
  }

  private static Consultor__c chooseOldest(List<Consultor__c> candidates) {
    Consultor__c selected;
    for (Consultor__c candidate : candidates) {
      if (candidate == null) {
        continue;
      }
      if (selected == null) {
        selected = candidate;
        continue;
      }
      DateTime currentDate = candidate.Lb065_UltimoLeadRecebido__c;
      DateTime selectedDate = selected.Lb065_UltimoLeadRecebido__c;
      if (selectedDate == null) {
        continue;
      }
      if (currentDate == null || currentDate < selectedDate) {
        selected = candidate;
      }
    }
    return selected;
  }

  private static List<String> splitCsv(String rawValue) {
    List<String> values = new List<String>();
    if (String.isBlank(rawValue)) {
      return values;
    }
    for (String part : rawValue.split(',')) {
      String trimmed = part != null ? part.trim() : null;
      if (!String.isBlank(trimmed)) {
        values.add(trimmed);
      }
    }
    return values;
  }
}
