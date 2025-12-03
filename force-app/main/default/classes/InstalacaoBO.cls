/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 12-03-2025
 * @last modified by  : Daniel Belini
**/
public class InstalacaoBO {

    public static void createInstallationsForFastTrackProjects(
        List<Projeto__c> projects,
        Map<Id, Opportunity> opportunityById
    ){
        if(projects == null || projects.isEmpty()){
            return;
        }

        List<Projeto__c> fastTrackProjects = new List<Projeto__c>();
        Set<Id> projectIds = new Set<Id>();

        for(Projeto__c project : projects){
            Opportunity opp = opportunityById != null ? opportunityById.get(project.Oportunidade__c) : null;
            if(opp != null && opp.Categoria__c != null && opp.Categoria__c.equalsIgnoreCase('Fast Track')){
                fastTrackProjects.add(project);
                projectIds.add(project.Id);
            }
        }

        if(fastTrackProjects.isEmpty()){
            return;
        }

        Map<Id, Instalacao__c> existingByProject = new Map<Id, Instalacao__c>();
        for(Instalacao__c inst : [
            SELECT Id, Projeto__c FROM Instalacao__c WHERE Projeto__c IN :projectIds
        ]){
            existingByProject.put(inst.Projeto__c, inst);
        }

        List<Instalacao__c> toInsert = new List<Instalacao__c>();
        for(Projeto__c project : fastTrackProjects){
            if(project.Instalacao__c != null || existingByProject.containsKey(project.Id)){
                continue;
            }
            toInsert.add(buildInstallation(project));
        }
        System.debug('### InstalacaoBO.createInstallationsForFastTrackProjects - toInsert: ' + toInsert);
        if(toInsert.isEmpty()){
            return;
        }

        insert toInsert;
        relateProjectsToInstallations(fastTrackProjects, toInsert);
    }

    public static void ensureInstallationOnProjectApproved(List<Projeto__c> newProjects, Map<Id, Projeto__c> oldMap){
        if(newProjects == null || newProjects.isEmpty()){
            return;
        }

        List<Projeto__c> toProcess = new List<Projeto__c>();
        Set<Id> projectIds = new Set<Id>();
        Set<Id> opportunityIdsToAdvance = new Set<Id>();

        for(Projeto__c project : newProjects){
            Projeto__c oldProject = oldMap != null ? oldMap.get(project.Id) : null;

            Boolean statusApproved =
                project.Status__c != null &&
                project.Status__c.equalsIgnoreCase(ProjetoUtils.STATUS_PROJETO_APROVADO) &&
                (oldProject == null || !project.Status__c.equalsIgnoreCase(oldProject.Status__c));

            Boolean approvalDateFilled =
                project.ApprovalDate__c != null &&
                (oldProject == null || project.ApprovalDate__c != oldProject.ApprovalDate__c);

            Boolean movedToApproved = statusApproved || approvalDateFilled;

            if(movedToApproved){
                if(project.Oportunidade__c != null){
                    opportunityIdsToAdvance.add(project.Oportunidade__c);
                }
                if(project.Instalacao__c == null){
                    toProcess.add(project);
                    projectIds.add(project.Id);
                }
            }
        }

        advanceOpportunitiesToPaymentConfirmation(opportunityIdsToAdvance);

        if(toProcess.isEmpty()){
            return;
        }

        Map<Id, Instalacao__c> existingByProject = new Map<Id, Instalacao__c>();
        for(Instalacao__c inst : [
            SELECT Id, Projeto__c FROM Instalacao__c WHERE Projeto__c IN :projectIds
        ]){
            existingByProject.put(inst.Projeto__c, inst);
        }

        List<Instalacao__c> toInsert = new List<Instalacao__c>();
        for(Projeto__c project : toProcess){
            if(existingByProject.containsKey(project.Id)){
                continue;
            }
            toInsert.add(buildInstallation(project));
        }

        if(toInsert.isEmpty()){
            return;
        }

        insert toInsert;
        relateProjectsToInstallations(toProcess, toInsert);
    }

    private static void advanceOpportunitiesToPaymentConfirmation(Set<Id> opportunityIds){
        if(opportunityIds == null || opportunityIds.isEmpty()){
            return;
        }

        List<Opportunity> opportunitiesToUpdate = new List<Opportunity>();
        for(Opportunity opp : [
            SELECT Id, StageName
            FROM Opportunity
            WHERE Id IN :opportunityIds
        ]){
            if(opp.StageName != null && opp.StageName.equalsIgnoreCase(OpportunityUtils.STATUS_PARECER_DE_ACESSO)){
                opportunitiesToUpdate.add(new Opportunity(
                    Id = opp.Id,
                    StageName = OpportunityUtils.STATUS_CONFIRMACAO_PAGAMENTO_CONTRATO
                ));
            }
        }

        if(!opportunitiesToUpdate.isEmpty()){
            update opportunitiesToUpdate;
        }
    }

    private static Instalacao__c buildInstallation(Projeto__c project){
        String installationName = project.Name != null ? 'Instalação - ' + project.Name : 'Instalação';
        installationName = truncateString(installationName, 80);

        return new Instalacao__c(
            Name                = installationName,
            Oportunidade__c     = project.Oportunidade__c,
            OportunidadeConcluida__c = project.Oportunidade__c,
            Projeto__c          = project.Id,
            GestorObra__c       = project.GestorObra__c,
            InstallDate__c      = project.InstallDate__c,
            DateInspection__c   = project.DateInspection__c
        );
    }

    private static void relateProjectsToInstallations(List<Projeto__c> projects, List<Instalacao__c> installations){
        Map<Id, Id> projectIdToInstallationId = new Map<Id, Id>();
        Map<Id, Id> projectIdToOpportunityId = new Map<Id, Id>();

        for(Instalacao__c installation : installations){
            if(installation.Projeto__c != null){
                projectIdToInstallationId.put(installation.Projeto__c, installation.Id);
            }
        }

        for(Projeto__c project : projects){
            if(project.Oportunidade__c != null){
                projectIdToOpportunityId.put(project.Id, project.Oportunidade__c);
            }
        }

        if(projectIdToInstallationId.isEmpty()){
            return;
        }

        List<Projeto__c> projectsToUpdate = new List<Projeto__c>();

        for(Projeto__c project : projects){
            Id installationId = projectIdToInstallationId.get(project.Id);

            if(installationId != null){
                projectsToUpdate.add(new Projeto__c(
                    Id = project.Id,
                    Instalacao__c = installationId
                ));
            }
        }

        if(!projectsToUpdate.isEmpty()){
            ProjetoTriggerHandler.disableTrigger();
            try{
                update projectsToUpdate;
            } finally {
                ProjetoTriggerHandler.enableTrigger();
            }
        }

        List<Instalacao__c> installationsToUpdate = new List<Instalacao__c>();
        for(Instalacao__c installation : installations){
            if(installation.Projeto__c != null){
                Id oppId = projectIdToOpportunityId.get(installation.Projeto__c);
                Boolean needsOppUpdate = oppId != null && oppId != installation.Oportunidade__c;
                if(needsOppUpdate){
                    installationsToUpdate.add(new Instalacao__c(
                        Id = installation.Id,
                        Oportunidade__c = oppId,
                        OportunidadeConcluida__c =  oppId
                    ));
                }
            }
        }

        if(!installationsToUpdate.isEmpty()){
            update installationsToUpdate;
        }
    }

    private static String truncateString(String value, Integer maxLength){
        if(value == null || maxLength == null || maxLength <= 0){
            return value;
        }
        return value.length() > maxLength ? value.substring(0, maxLength) : value;
    }
}
