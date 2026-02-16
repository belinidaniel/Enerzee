/**
 * @description       : 
 * @author            : Daniel Belini
 * @group             : 
 * @last modified on  : 10-20-2025
 * @last modified by  : Daniel Belini
**/
trigger ContentDocumentLinkTrigger on ContentDocumentLink (after insert, after update, after delete) {
    if (Trigger.isInsert || Trigger.isUpdate) {
        for (ContentDocumentLink cdl : Trigger.new) {
            if (cdl.LinkedEntityId.getSObjectType() == Task.SObjectType) {
                Task task = [SELECT Id, WhatId FROM Task WHERE Id = :cdl.LinkedEntityId];
                if (task.WhatId != null) {
                    ContentDocumentLink projectLink = new ContentDocumentLink(
                        ContentDocumentId = cdl.ContentDocumentId,
                        LinkedEntityId = task.WhatId,
                        ShareType = 'V'
                    );
                    insert projectLink;
                }
                
            } else if (cdl.LinkedEntityId.getSObjectType() == Account.sObjectType) {
                Account acc = [SELECT Id, Name FROM Account WHERE Id = :cdl.LinkedEntityId LIMIT 1]; 
                if (acc != null) { 
                    List<Messaging.SingleEmailMessage> messageList = new List<Messaging.SingleEmailMessage>();
                    messageList.add(EmailUtils.createSingleEmailMessage(
                        'Relatório Diário de Obras - '+ acc.Name,

                        'Olá! Foi anexado ao cliente: ' + acc.Name + ', o relatório diário de obras.' + '<br>' +
                        'Clique no link abaixo para conferir.<br><br>' +
                        (URL.getOrgDomainUrl().toExternalForm() + '/lightning/r/Account/' + acc.Id + '/view'),

                        new String[]{ 'daniel.belini@enerzee.com.br' },
                        new String[]{ 'daniel.belini@enerzee.com.br' }
                    ));

                    if(!Test.isRunningTest()){
                        // Messaging.SendEmailResult[] results = Messaging.sendEmail(messageList);
                    }
                }
            }
        }
    }
    
    if (Trigger.isDelete) {
        for (ContentDocumentLink cdl : Trigger.old) {
            if (cdl.LinkedEntityId.getSObjectType() == Task.SObjectType) {
                Task task = [SELECT Id, WhatId FROM Task WHERE Id = :cdl.LinkedEntityId];
                if (task.WhatId != null) {
                    List<ContentDocumentLink> projectLinks = [
                        SELECT Id FROM ContentDocumentLink
                        WHERE ContentDocumentId = :cdl.ContentDocumentId
                        AND LinkedEntityId = :task.WhatId
                    ];
                    delete projectLinks;
                }
            }
        }
    }
}
