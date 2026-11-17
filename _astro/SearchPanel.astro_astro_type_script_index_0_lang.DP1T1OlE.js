const g=["composer","conductor","orchestra","workGroup","work","recording","article","person"];const L=["composer","conductor","orchestra","work","recording","article","person"];function h(e){return String(e??"").normalize("NFKC").toLowerCase().replace(/[路，。,'"“”‘’`?:;!()[\]{}\\/_-]+/g," ").replace(/\s+/g," ").trim()}function I(e,n){if(!n)return!0;const t=n.split(" ").filter(Boolean),r=[...e.matchTokens??[],...e.aliasTokens??[],e.primaryText,e.secondaryText].map(a=>h(a)).filter(Boolean);return t.every(a=>r.some(i=>i.includes(a)))}function v(e,n,t,r={}){const a=h(n),i=Math.max(1,Number(r.previewLimit)||5),o=Math.max(1,Number(r.queryPageSize)||10),l=new Map;for(const s of e||[]){if(!L.includes(s.kind)||!I(s,a))continue;const c=l.get(s.kind)??[];c.push(s),l.set(s.kind,c)}const p=g.filter(s=>L.includes(s)&&l.has(s)).map(s=>{const c=l.get(s)??[];if(!a)return{kind:s,page:1,pageSize:i,totalItems:c.length,totalPages:1,items:c.slice(0,i)};const _=Math.max(1,Math.ceil(c.length/o)),P=Math.min(Math.max(1,Number(t?.[s])||1),_),w=(P-1)*o;return{kind:s,page:P,pageSize:o,totalItems:c.length,totalPages:_,items:c.slice(w,w+o)}});if(!a)return p;const E=g.filter(s=>(Number(t?.[s])||1)>1);return E.length?p.filter(s=>E.includes(s.kind)):p}const M=/^[a-zA-Z][a-zA-Z\d+\-.]*:/;function $(e){const n=String(e||"/").trim();if(!n||n==="/")return"/";const t=n.startsWith("/")?n:`/${n}`;return t.endsWith("/")?t:`${t}/`}function b(e,n="/"){const t=String(e||"").trim();if(!t)return $(n);if(t.startsWith("#")||t.startsWith("?")||t.startsWith("//")||M.test(t)||!t.startsWith("/"))return t;const r=$(n);if(r==="/")return t;const a=r.slice(0,-1);return t===a||t.startsWith(r)?t:t==="/"?r:`${r}${t.slice(1)}`}function T(e,n="/introduction-to-classical-music-sites/"){return b(e,n)}const k=window.__SEARCH_PANEL_ITEMS__||[],S=document.querySelector("[data-search-panel]"),x=S?.querySelector("[data-search-form]"),m=S?.querySelector("[data-search-input]"),d=S?.querySelector("[data-search-results]"),N={composer:"作曲家",conductor:"指挥",orchestra:"乐团",workGroup:"类型",work:"作品",recording:"版本",article:"专栏",person:"人物"},u=e=>String(e??"").replaceAll("&","&amp;").replaceAll("<","&lt;").replaceAll(">","&gt;").replaceAll('"',"&quot;"),R=e=>Object.fromEntries(g.map(n=>[n,Math.max(1,Number(e.get(`page-${n}`)||1)||1)])),f=(e,n)=>{const t=new URLSearchParams;e&&t.set("q",e);for(const[i,o]of Object.entries(n||{}))Number(o)>1&&t.set(`page-${i}`,String(o));const r=t.toString(),a=T("/search/");return r?`${a}?${r}`:a},z=(e,n,t)=>{if(!h(n)||e.totalPages<=1)return"";const r=Math.max(1,e.page-1),a=Math.min(e.totalPages,e.page+1);return`
      <div class="search-group__pagination">
        <span>第 ${e.page} / ${e.totalPages} 页</span>
        <div class="search-group__pagination-links">
          <a href="${u(f(n,{...t,[e.kind]:r}))}" ${e.page<=1?'aria-disabled="true"':""}>上一页</a>
          <a href="${u(f(n,{...t,[e.kind]:a}))}" ${e.page>=e.totalPages?'aria-disabled="true"':""}>下一页</a>
        </div>
      </div>
    `},A=()=>{if(!d)return;const e=new URLSearchParams(window.location.search),n=e.get("q")??"",t=R(e),r=!!h(n),a=v(k,n,t);if(m instanceof HTMLInputElement&&(m.value=n),!a.length){d.innerHTML='<p class="page-note">没有找到匹配项。</p>';return}d.innerHTML=a.map(i=>{const o=i.items.map(l=>`
              <li class="search-result">
                <a href="${u(T(l.href))}">
                  <strong>${u(l.primaryText)}</strong>
                  <span>${u(l.secondaryText??"")}</span>
                </a>
              </li>
            `).join("");return`
          <section class="search-group">
            <div class="search-group__header">
              <h2>${N[i.kind]}</h2>
              <span>${i.items.length} / ${i.totalItems}</span>
            </div>
            <ul>${o}</ul>
            ${r?z(i,n,t):""}
          </section>
        `}).join("")};x?.addEventListener("submit",e=>{if(e.preventDefault(),!(m instanceof HTMLInputElement))return;const n=m.value.trim();window.location.assign(f(n,{}))});window.addEventListener("popstate",A);A();
