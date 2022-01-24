xquery version "3.1";

declare variable $xconf :=
    <collection xmlns="http://exist-db.org/collection-config/1.0">
    <index xmlns:xs="http://www.w3.org/2001/XMLSchema">
         <lucene>
          <analyzer class="org.apache.lucene.analysis.standard.StandardAnalyzer"/>
          <analyzer id="ws" class="org.apache.lucene.analysis.core.WhitespaceAnalyzer"/>
          <text qname="l"/>
        </lucene>
    </index>
</collection>;

let $doc := doc('mac.xml')

let $icol := '04_ftquery'
let $set-up := ( xmldb:create-collection("/db/system/config/db", $icol),
            xmldb:store("/db/system/config/db/" || $icol, "collection.xconf", $xconf),
            xmldb:reindex("/db/" || $icol)
        )

return

    //l[ft:query(., 'cauldron')]