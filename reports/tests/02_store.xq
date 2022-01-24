xquery version "3.1";

let $doc := <root> 
    { for $e in 1 to 1000
    return
        <el>{$e}</el>
    }
    </root>
    
let $icol := 'test-store5/'
let $store-col := xmldb:create-collection('/db/', $icol)

for $i in 1 to 500
return
    xmldb:store('/db/' || $icol, $i || '.xml', $doc)