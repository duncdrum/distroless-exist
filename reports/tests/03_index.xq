xquery version "3.1";

declare variable $xconf :=
    <collection xmlns="http://exist-db.org/collection-config/1.0">
    <index xmlns:xs="http://www.w3.org/2001/XMLSchema">
        <range>
            <create qname="el" type="xs:integer"/>
        </range>
    </index>
</collection>;

let $icol := 'test-store5/'
let $set-up := xmldb:create-collection("/db/system/config/db", $icol)
    return
        (
            xmldb:store("/db/system/config/db/" || $icol, "collection.xconf", $xconf),
            xmldb:reindex("/db/" || $icol)
        )

