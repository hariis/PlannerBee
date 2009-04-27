 tag_delimitor = ","  
   
 function swap_tag(tag,elem)  
 {  
     swap_tag(tag,elem,true)  
 }  
 function swap_tag(tag,elem,change_case){  
     if (change_case == true) {  
         tag = trim(tag).toLowerCase();  
     }  
     else {  
         tag = trim(tag)  
     }  
     tags = document.getElementById(elem)  
     var tagArray = trim(tags.value).split(tag_delimitor)  
     var present = false;  
     if (trim(tagArray[0]) == '') tagArray.splice(0,1);  
     for (t=0; t<tagArray.length; t++) {  
         if (trim(tagArray[t]).toLowerCase() == tag || (change_case == false && trim(tagArray[t]) == tag) )   
         {   
           tagArray.splice(t,1);   
           present=true;  
           t-=1;    
         }  
     }  
     if (!present) { tagArray.push(tag); }  
     var content = tagArray.join(tag_delimitor)  
     //tags.value = (content.length > 1) ? content + ', ' : content  
     tags.value = content;  
     //focusTo(tags)  
 }  
   
 function trim(str)  
 {  
    return str.replace(/^\s*|\s*$/g,"");  
 }  