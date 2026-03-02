/**
 * @description						 : Helper service to persist external attachments linked to Opportunities.
 * @author											 : Daniel Belini
 **/
public with sharing class OpportunityAttachmentLinkService {
  private static final Integer MAX_NAME_LENGTH = 80;

  public class AttachmentInput {
    public Id opportunityId;
    public String attachmentUrl;
    public String description;
    public String externalId;
    public String type;
  }

  public static void upsertAttachment(AttachmentInput input) {
    if (
      input == null ||
      input.opportunityId == null ||
      String.isBlank(input.attachmentUrl)
    ) {
      return;
    }

    OpportunityAttachmentLink__c record = new OpportunityAttachmentLink__c();
    record.OpportunityId__c = input.opportunityId;
    record.AttachmentURL__c = input.attachmentUrl;
    record.Type__c = String.isNotBlank(input.type) ? input.type : 'Other';
    record.Name = buildName(input.description);

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

  private static String buildName(String description) {
    String candidate = String.isNotBlank(description)
      ? description.trim()
      : 'Attachment ' + String.valueOf(DateTime.now().getTime());
    return candidate.length() > MAX_NAME_LENGTH
      ? candidate.substring(0, MAX_NAME_LENGTH)
      : candidate;
  }
}
