public with sharing class ServiceAppointmentBO {
  public static void sendTechnicalVisitDate(
    Map<Id, ServiceAppointment> newRecordsMap
  ) {
    IntegracaoNivelloDataVisitaTecnica.sendTechnicalVisitDate(
      newRecordsMap.keySet(),
      true
    );
  }

  public static void assignScheduledStartAndEndTime(
    List<ServiceAppointment> newRecords
  ) {
    for (ServiceAppointment app : newRecords) {
      if (app.FSL__IsMultiDay__c == false) {
        app.SchedStartTime = app.EarliestStartTime;
        app.SchedEndTime = app.DueDate;
      }
    }
  }

  public static void assignVisitDateTimeOnOpportunity(
    List<ServiceAppointment> newRecords,
    Map<Id, ServiceAppointment> oldRecordsMap
  ) {
    Map<Id, Opportunity> contextOpportunitiesMap = new Map<Id, Opportunity>(
      [
        SELECT Id, PrazoAprovacaoViabilidade__c, StageName
        FROM Opportunity
        WHERE
          Id IN :Collection.of(newRecords)
            .pluckNotNullStrings(ServiceAppointment.Oportunidade__c)
      ]
    );

    List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
    for (ServiceAppointment app : newRecords) {
      Opportunity opp = contextOpportunitiesMap.get(app.Oportunidade__c);

      if (opp != null) {
        if (Trigger.isInsert) {
          if (app.SchedStartTime != null) {
            opp.PrazoAprovacaoViabilidade__c = app.SchedStartTime;
            opp.StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE;

            opportunitiesToUpdate.add(opp);
          }
        }

        if (Trigger.isUpdate) {
          if (
            app.SchedStartTime != oldRecordsMap.get(app.Id).SchedStartTime &&
            app.SchedStartTime != null
          ) {
            opp.PrazoAprovacaoViabilidade__c = app.SchedStartTime;
            opp.StageName = OpportunityUtils.STATUS_ANALISE_DE_VIABILIDADE;

            opportunitiesToUpdate.add(opp);
          }
        }
      }
    }
    update opportunitiesToUpdate;
  }

  public static void updateRespectiveOpportunityFields(
    List<ServiceAppointment> newRecords,
    Map<Id, ServiceAppointment> oldRecordsMap
  ) {
    Map<Id, Opportunity> opportunityMap = new Map<Id, Opportunity>(
      [
        SELECT
          Id,
          Equipe_Propria_ou_Terceira__c,
          ResponsavelVisita__c,
          Duracao_estimada_da_visita_em_minutos__c
        FROM Opportunity
        WHERE
          Id IN :Collection.of(newRecords)
            .pluckNotNullStrings(ServiceAppointment.Oportunidade__c)
      ]
    );

    for (ServiceAppointment app : newRecords) {
      Opportunity opportunity = opportunityMap.get(app.Oportunidade__c);

      if (Trigger.isInsert) {
        if (opportunity == null) {
          app.addError('Favor inserir a oportunidade!');
        } else {
          opportunity.Equipe_Propria_ou_Terceira__c = app.Equipe_Propria_ou_Terceira__c;
          opportunity.ResponsavelVisita__c = app.ResponsavelVisita__c;
          opportunity.Duracao_estimada_da_visita_em_minutos__c = app.DurationInMinutes;
        }
      }

      if (Trigger.isUpdate) {
        ServiceAppointment oldApp = oldRecordsMap.get(app.Id);

        if (
          app.Equipe_Propria_ou_Terceira__c !=
          oldApp.Equipe_Propria_ou_Terceira__c
        ) {
          opportunity.Equipe_Propria_ou_Terceira__c = app.Equipe_Propria_ou_Terceira__c;
        }

        if (app.ResponsavelVisita__c != oldApp.ResponsavelVisita__c) {
          opportunity.ResponsavelVisita__c = app.ResponsavelVisita__c;
        }

        if (app.DurationInMinutes != oldApp.DurationInMinutes) {
          opportunity.Duracao_estimada_da_visita_em_minutos__c = app.DurationInMinutes;
        }
      }
    }

    update opportunityMap.values();
  }

  public static void assignOpportunityToAppointment(
    List<ServiceAppointment> newRecords
  ) {
    List<String> workOrderIds = new List<String>();

    for (ServiceAppointment appointment : newRecords) {
      Id parentId = appointment.ParentRecordId;
      if (
        parentId != null &&
        parentId.getSObjectType() == Schema.SObjectType.WorkOrder.SObjectType
      ) {
        workOrderIds.add(parentId);
      }
    }

    if (!workOrderIds.isEmpty()) {
      Map<Id, WorkOrder> workOrdersById = new Map<Id, WorkOrder>(
        [
          SELECT Id, Oportunidade__c
          FROM WorkOrder
          WHERE Id IN :workOrderIds
        ]
      );

      for (ServiceAppointment appointment : newRecords) {
        appointment.Oportunidade__c = workOrdersById.get(
            appointment.ParentRecordId
          )
          .Oportunidade__c;
      }
    }
  }

  public static void updateAndCloneServiceAppointments(
    List<ServiceAppointment> appointments
  ) {
    Set<Id> assignedResourceIds = new Set<Id>();
    for (ServiceAppointment appointment : appointments) {
      assignedResourceIds.add(appointment.Id);
    }

    Map<Id, User> usersMap = new Map<Id, User>(
      [SELECT Id FROM User WHERE Id IN :assignedResourceIds]
    );

    List<ServiceAppointment> newAppointments = new List<ServiceAppointment>();

    for (ServiceAppointment appointment : appointments) {
      //Id assignedResourceId = appointment.AssignedResource__c;
      //User user = usersMap.get(assignedResourceId);

      //if (user != null) {
      //DateTime startDateTime = appointment.StartDateTime;
      //DateTime endDateTime = appointment.EndDateTime;
      //Integer durationMinutes = appointment.DurationMinutes__c;

      //DateTime userWorkStartDateTime = startDateTime.newInstanceGmt(startDateTime.date(), user.WorkStartTime__c);
      //DateTime userWorkEndDateTime = startDateTime.newInstanceGmt(startDateTime.date(), user.WorkEndTime__c);

      /*if (startDateTime < userWorkStartDateTime || endDateTime > userWorkEndDateTime) {
					// O horário do compromisso de serviço está fora do horário de trabalho do usuário de campo
					
					// Dividir a atividade em duas partes
					//Integer remainingMinutes = Math.max(0, (Integer)userWorkEndDateTime.minutesBetween(startDateTime));
					
					// Atualizar a duração do compromisso de serviço atual
					//appointment.DurationMinutes__c = remainingMinutes;
					
					// Criar um novo compromisso de serviço para o restante da atividade
					ServiceAppointment newAppointment = appointment.clone(false, true);
					//newAppointment.StartDateTime = userWorkEndDateTime;
					//newAppointment.DurationMinutes__c = durationMinutes - remainingMinutes;
					
					newAppointments.add(newAppointment);
				}*/
      //}
    }

    // Atualizar os compromissos de serviço existentes
    update appointments;

    // Inserir os novos compromissos de serviço
    insert newAppointments;
  }
}
