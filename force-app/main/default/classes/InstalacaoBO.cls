/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 11-21-2025
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

        Set<Id> projectIds = new Set<Id>();
        Set<Id> opportunityIds = new Set<Id>();

        for(Projeto__c project : projects){
            Opportunity opportunity = opportunityById.get(project.Oportunidade__c);
            if(opportunity != null && opportunity.Categoria__c != null && opportunity.Categoria__c.equalsIgnoreCase('Fast Track')){
                projectIds.add(project.Id);
                opportunityIds.add(project.Oportunidade__c);
            }
        }

        if(opportunityIds.isEmpty()){
            return;
        }

        Map<Id, Instalacao__c> projectIdToInstallation = new Map<Id, Instalacao__c>();
        Map<Id, Instalacao__c> opportunityIdToInstallation = new Map<Id, Instalacao__c>();
        Map<Id, Instalacao__c> installationsToUpdate = new Map<Id, Instalacao__c>();

        for(Instalacao__c existingInstallation : [
            SELECT  Id, Projeto__c, Oportunidade__c
            FROM    Instalacao__c
            WHERE   Projeto__c IN :projectIds
                OR  Oportunidade__c IN :opportunityIds
        ]){
            if(existingInstallation.Projeto__c != null && !projectIdToInstallation.containsKey(existingInstallation.Projeto__c)){
                projectIdToInstallation.put(existingInstallation.Projeto__c, existingInstallation);
            }
            if(existingInstallation.Oportunidade__c != null && !opportunityIdToInstallation.containsKey(existingInstallation.Oportunidade__c)){
                opportunityIdToInstallation.put(existingInstallation.Oportunidade__c, existingInstallation);
            }
        }

        List<Instalacao__c> installationsToInsert = new List<Instalacao__c>();

        for(Projeto__c project : projects){
            Opportunity opportunity = opportunityById.get(project.Oportunidade__c);

            if(opportunity == null || opportunity.Categoria__c == null || !opportunity.Categoria__c.equalsIgnoreCase('Fast Track')){
                continue;
            }

            Instalacao__c oppInstallation = opportunityIdToInstallation.get(project.Oportunidade__c);
            if(oppInstallation != null){
                // Existe instalação para a oportunidade; se não estiver vinculada ao projeto, vincular
                if(oppInstallation.Projeto__c == null){
                    oppInstallation.Projeto__c = project.Id;
                    installationsToUpdate.put(oppInstallation.Id, oppInstallation);
                }
                if(project.Instalacao__c == null && !installationsToUpdate.containsKey(oppInstallation.Id)){
                    installationsToUpdate.put(oppInstallation.Id, oppInstallation);
                }
                continue;
            }

            if(projectIdToInstallation.containsKey(project.Id)){
                continue;
            }

            installationsToInsert.add(buildInstallation(project));
        }

        if(!installationsToInsert.isEmpty()){
            insert installationsToInsert;
            relateProjectsToInstallations(projects, installationsToInsert);
        }

        if(!installationsToUpdate.isEmpty()){
            update installationsToUpdate.values();
            relateProjectsToInstallations(projects, installationsToUpdate.values());
        }
    }

    public static void ensureInstallationOnProjectApproved(List<Projeto__c> newProjects, Map<Id, Projeto__c> oldMap){
        if(newProjects == null || newProjects.isEmpty()){
            return;
        }

        List<Projeto__c> toProcess = new List<Projeto__c>();
        Set<Id> projectIds = new Set<Id>();

        for(Projeto__c project : newProjects){
            Projeto__c oldProject = oldMap != null ? oldMap.get(project.Id) : null;

            Boolean movedToApproved =
                project.Status__c != null &&
                project.Status__c.equalsIgnoreCase(ProjetoUtils.STATUS_PROJETO_APROVADO) &&
                (oldProject == null || !project.Status__c.equalsIgnoreCase(oldProject.Status__c));

            if(movedToApproved && project.Instalacao__c == null){
                toProcess.add(project);
                projectIds.add(project.Id);
            }
        }

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

    private static Instalacao__c buildInstallation(Projeto__c project){
        String installationName = project.Name != null ? 'Instalação - ' + project.Name : 'Instalação';

        return new Instalacao__c(
            Name                = installationName,
            Oportunidade__c     = project.Oportunidade__c,
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
            if(installation.Oportunidade__c == null && installation.Projeto__c != null){
                Id oppId = projectIdToOpportunityId.get(installation.Projeto__c);
                if(oppId != null){
                    installationsToUpdate.add(new Instalacao__c(
                        Id = installation.Id,
                        Oportunidade__c = oppId
                    ));
                }
            }
        }

        if(!installationsToUpdate.isEmpty()){
            update installationsToUpdate;
        }
    }
}
