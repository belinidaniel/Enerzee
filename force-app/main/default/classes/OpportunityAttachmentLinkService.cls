/**
 * @description       : Helper service to persist external attachments linked to Opportunities.
 * @author            : Daniel Belini
**/
public with sharing class OpportunityAttachmentLinkService {

    public class AttachmentInput {
        public Id opportunityId;
        public String attachmentUrl;
        public String description;
        public String externalId;
        public String type;
    }

    public static void upsertAttachment(AttachmentInput input) {
        if (input == null
            || input.opportunityId == null
            || String.isBlank(input.attachmentUrl)) {
            return;
        }

        OpportunityAttachmentLink__c record = new OpportunityAttachmentLink__c();
        record.OpportunityId__c = input.opportunityId;
        record.AttachmentURL__c = input.attachmentUrl;
        record.Type__c = String.isNotBlank(input.type) ? input.type : 'Other';
        // Name tem limite de 80 chars; garantir truncamento para evitar DML error.
        String baseName = String.isNotBlank(input.description)
            ? input.description
            : 'Attachment ' + String.valueOf(DateTime.now().getTime());
        record.Name = baseName.length() > 80 ? baseName.substring(0, 80) : baseName;

        if (String.isNotBlank(input.description)) {
            record.AttachmentDescription__c = input.description;
        }
        if (String.isNotBlank(input.externalId)) {
            record.ExternalId__c = input.externalId;
        }

        if (String.isNotBlank(record.ExternalId__c)) {
            upsert record ExternalId__c;
        } else {
            insert record;
        }
    }
}
