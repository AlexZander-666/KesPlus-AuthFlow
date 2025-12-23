-- 随机为学生分配姓名（演示用）
-- 在 04_seed_data_course_selection.sql 之后执行
DO $$
DECLARE
  name_pool TEXT[] := ARRAY[
    'Liam Chen', 'Noah Lin', 'Emma Zhou', 'Olivia Wei', 'Ava Liu',
    'Sophia Zhang', 'Isabella Sun', 'Mia Guo', 'Ethan Wu', 'Lucas Huang',
    'Mason He', 'Logan Xiao', 'Grace Luo', 'Chloe Deng', 'Zoe Ma'
  ];
  pool_len INT;
BEGIN
  pool_len := array_length(name_pool, 1);

  -- 随机打散学生列表，并循环使用姓名池
  WITH ranked AS (
    SELECT stu_id,
           ((ROW_NUMBER() OVER (ORDER BY random()) - 1) % pool_len) + 1 AS idx
    FROM tb_student
  ), assigned AS (
    SELECT r.stu_id, name_pool[r.idx] AS new_name
    FROM ranked r
  )
  UPDATE tb_student s
  SET stu_name = a.new_name
  FROM assigned a
  WHERE s.stu_id = a.stu_id;

  -- 同步 TB_USER.real_name
  UPDATE tb_user u
  SET real_name = s.stu_name
  FROM tb_student s
  WHERE u.user_id = s.user_id
    AND u.role = 'STUDENT';
END $$;
