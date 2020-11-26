# Defined in - @ line 1
function art --wraps='php artisan' --description 'alias art php artisan'
  php artisan $argv;
end
