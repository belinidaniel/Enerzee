public without sharing class ContentVersionBO {

    public ContentVersionBO() {

    }

    public static void fillIsProposal(List<ContentVersion> versions){

        try{

            for(ContentVersion version : versions){
                if(!version.IsProposal__c)
                    version.IsProposal__c = version.Title.containsIgnoreCase('proposta') || version.Title.containsIgnoreCase('P-') ;
            }

        }catch(Exception ex){
            System.debug('##Erro ao preencher flag de proposta: ' + ex.getMessage());
            System.debug('##Stack: ' + ex.getStackTraceString());
            System.debug('##Line: ' + ex.getLineNumber());
        }
        
    }
}