CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

ALTER TABLE UM_USER
    ADD COLUMN UM_USER_ID CHAR(36) DEFAULT uuid_generate_v4(),
    ADD CONSTRAINT UM_USER_UUID_CONSTRAINT UNIQUE(UM_USER_ID);


CREATE OR REPLACE FUNCTION update_um_user_id()	returns int 
LANGUAGE plpgsql
AS $$
DECLARE 
count_rows int;
cur_um_attr cursor for select T2.um_attr_value, T1.um_id
          from um_user_attribute  T2
            join um_user T1
            on T1.um_Id = T2.um_user_id 
            where T2.um_attr_name ='scimId';
          
rec_um_attr RECORD;		
BEGIN
  count_rows = 0;	
  open cur_um_attr;
    LOOP
          fetch cur_um_attr into rec_um_attr;
      exit when not found;
  
        update um_user
        set um_user_id=rec_um_attr.um_attr_value
        where um_id = rec_um_attr.um_id;	
      
    count_rows = count_rows + 1;
    END LOOP;			
  close cur_um_attr;
return count_rows;		
END;
$$;
select update_um_user_id();
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
update um_user set um_user_id=uuid_generate_v4() where um_user_id = 'N';