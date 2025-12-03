public class TaskTemplateUtils {

    private static final Integer DEFAULT_DUE_HOUR = 17;

    public static Date calculateDueDate(Date startDate, String prazoDiasUteis, String dataVencimentoDMais){
        Integer workingDays = parseInteger(prazoDiasUteis, null);
        if(workingDays == null){
            workingDays = parseInteger(dataVencimentoDMais, 0);
        }
        if(workingDays == null){
            workingDays = 0;
        }
        Date base = startDate != null ? startDate : System.today();
        return TaskBO.getActivityDateBasedOnWorkingDays(base, workingDays);
    }

    public static Time defaultDueTime(){
        return Time.newInstance(DEFAULT_DUE_HOUR, 0, 0, 0);
    }

    public static DateTime combineDateAndTime(Date activityDate, Object horaVencimento){
        if(activityDate == null){
            return null;
        }

        Time dueTime;
        if(horaVencimento instanceof Time){
            dueTime = (Time) horaVencimento;
        } else if(horaVencimento instanceof DateTime){
            DateTime dtValue = (DateTime) horaVencimento;
            dueTime = Time.newInstance(dtValue.hour(), dtValue.minute(), dtValue.second(), dtValue.millisecond());
        } else {
            dueTime = defaultDueTime();
        }

        return DateTime.newInstance(activityDate, dueTime);
    }

    public static Id resolveOwner(
        ProjetoBO.TaskProjectTableLine line,
        Map<String, User> roleToUser,
        Map<String, Group> queueMap,
        SObject parentRecord
    ){
        String ownerType = sanitizeOwnerType(line != null ? line.TipoDeProprietario : null);
        String responsavel = line != null ? String.valueOf(line.Responsavel).trim() : null;
        String normalizedKey = normalizeKey(responsavel);
        String normalizedType = normalizeKey(ownerType);

        if('QUEUE'.equals(ownerType)){
            Group queue = null;
            if(queueMap != null){
                queue = queueMap.get(normalizedKey);
            }
            return queue != null ? queue.Id : null;
        }

        if(ownerType == 'ROLE'){
            if(roleToUser != null){
                User roleUser = roleToUser.get(responsavel);
                if(roleUser == null && normalizedKey != null){
                    roleUser = roleToUser.get(normalizedKey);
                }
                if(roleUser != null && roleUser.IsActive){
                    return roleUser.Id;
                }
            }
            // fallback: buscar usuário ativo com UserRole.DeveloperName igual ao responsavel normalizado
            Id roleUserId = getUserIdByRole(normalizedKey);
            if(roleUserId != null){
                return roleUserId;
            }
            return null;
        }

        if(ownerType == 'USUARIO'){
            if(responsavel != null && responsavel.trim().equalsIgnoreCase('OWNER')){
                if(parentRecord != null && parentRecord.getSObjectType().getDescribe().fields.getMap().containsKey('OwnerId')){
                    return (Id) parentRecord.get('OwnerId');
                }
            } else {
                User targetUser = roleToUser != null ? roleToUser.get(responsavel) : null;
                if(targetUser == null && normalizedKey != null){
                    targetUser = roleToUser != null ? roleToUser.get(normalizedKey) : null;
                }
                if(targetUser == null){
                    targetUser = getUserByEmail(responsavel);
                }
                if(targetUser != null && targetUser.IsActive){
                    return targetUser.Id;
                }
            }
            return null;
        }

        if(roleToUser != null && !String.isBlank(responsavel)){
            User user = roleToUser.get(responsavel);
            if(user == null && normalizedKey != null){
                user = roleToUser.get(normalizedKey);
            }
            if(user != null && user.IsActive){
                return user.Id;
            }
        }
        if(queueMap != null){
            Group queue = null;
            if(normalizedKey != null){
                queue = queueMap.get(normalizedKey);
            }
            if(queue == null && normalizedType != null){
                queue = queueMap.get(normalizedType);
            }
            if(queue != null){
                return queue.Id;
            }
        }
        return null;
    }

    public static Integer parseInteger(String value, Integer defaultValue){
        if(String.isBlank(value)){
            return defaultValue;
        }
        try{
            return Integer.valueOf(value.replaceAll('[^0-9-]', ''));
        } catch (Exception ex){
            return defaultValue;
        }
    }

    private static String sanitizeOwnerType(String ownerType){
        if(String.isBlank(ownerType)){
            return 'LOOKUP';
        }
        return ownerType.trim().toUpperCase();
    }

    private static String normalizeKey(String value){
        if(String.isBlank(value)){
            return '';
        }
        String normalized = value.trim().replace(' ', '_').toUpperCase();
        return normalized;
    }

    private static Map<String, Id> roleKeyToUserId = new Map<String, Id>();
    private static Id getUserIdByRole(String normalizedRoleKey){
        if(String.isBlank(normalizedRoleKey)){
            return null;
        }
        if(roleKeyToUserId.containsKey(normalizedRoleKey)){
            return roleKeyToUserId.get(normalizedRoleKey);
        }
        List<User> users = [
            SELECT Id
            FROM User
            WHERE IsActive = true
            AND UserRole.DeveloperName = :normalizedRoleKey
            LIMIT 1
        ];
        Id result = users.isEmpty() ? null : users[0].Id;
        roleKeyToUserId.put(normalizedRoleKey, result);
        return result;
    }

    private static User getUserByEmail(String email){
        if(String.isBlank(email)){
            return null;
        }

        List<User> users = [
            SELECT Id, Email, IsActive
            FROM User
            WHERE IsActive = true
            AND Email LIKE :email + '%'
            LIMIT 1
        ];

        return users.isEmpty() ? null : users[0];
    }
}
