public class TaskWhoName {
	@InvocableMethod(label = 'Get Who Name')
    public static List<String> getWhoName(List<Task> tasks) {
        List<String> whoNames = new List<String>();
        
        for (Task task : tasks) {
            if (task.WhoId != null) {
                id pcID  = task.whoId; 
                
        		String whoIdsObjectType  = task.whoId.getSObjectType().getDescribe().getName(); 

                Map<String, List<String>> objectFieldMap = new Map<String, List<String>>{
                    'Contact'   => new List<String>{'Name'},
                    'Lead'      => new List<String>{'Title'}
                };
            
                List<String> fieldsToQuery = objectFieldMap.containsKey(whoIdsObjectType) 
                    ? objectFieldMap.get(whoIdsObjectType) 
                    : new List<String>{'Id'};
            
                String query = 'SELECT ' + String.join(fieldsToQuery, ', ') + ' FROM ' + whoIdsObjectType + ' WHERE Id =: pcID';
                List<SObject> relatedRecords = Database.query(query);
            
                if (!relatedRecords.isEmpty()) {
                    SObject relatedRecord = relatedRecords[0];
                    String displayValue = '';
            
                    for (String field : fieldsToQuery) {
                        if (relatedRecord.get(field) != null) {
                            displayValue += (displayValue != '' ? ' - ' : '') + String.valueOf(relatedRecord.get(field));
                        }
                    }
            
                    whoNames.add(displayValue);
                }
                
            } else {
                whoNames.add(null);
            }
        }
        
        return whoNames;
    }
}