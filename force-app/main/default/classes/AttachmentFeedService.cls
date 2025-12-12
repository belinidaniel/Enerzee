public with sharing class AttachmentFeedService {
    @AuraEnabled
    public static void publishAttachmentNote(Id parentId, List<String> fileNames, String activityLabel) {
        if (parentId == null) {
            throw new AuraHandledException('Record Id is required.');
        }

        List<String> sanitizedNames = new List<String>();
        if (fileNames != null) {
            for (String name : fileNames) {
                if (!String.isBlank(name)) {
                    sanitizedNames.add(name);
                }
            }
        }

        String userName = UserInfo.getName();
        String subjectText = String.isNotBlank(activityLabel) ? activityLabel : 'atividade';
        String filesText = sanitizedNames.isEmpty() ? 'arquivo' : 'arquivo(s): ' + String.join(sanitizedNames, ', ');

        FeedItem post = new FeedItem();
        post.ParentId = parentId;
        post.Body = userName + ' anexou ' + filesText + ' na ' + subjectText + '.';
        insert post;
    }
}
