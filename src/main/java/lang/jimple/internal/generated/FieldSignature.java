package lang.jimple.internal.generated;

import lang.jimple.internal.JimpleAbstractDataType; 
import java.util.List; 

import lombok.*; 

import io.usethesource.vallang.IConstructor;
import io.usethesource.vallang.IList;
import io.usethesource.vallang.IValue;
import io.usethesource.vallang.IValueFactory; 

@Builder
@EqualsAndHashCode
public  class FieldSignature extends JimpleAbstractDataType {
   @Override 
   public String getBaseType() { 
     return "FieldSignature";
   } 

   
     
      
       public String className;
      
       public Type fieldType;
      
       public String fieldName;
      
     
      public static FieldSignature fieldSignature(String className, Type fieldType, String fieldName)  {
        return new FieldSignature(className, fieldType, fieldName);
      }
      
        public FieldSignature(String className, Type fieldType, String fieldName) {
         
           this.className = className;  
         
           this.fieldType = fieldType;  
         
           this.fieldName = fieldName;  
           
        } 
      @Override
      public IConstructor createVallangInstance(IValueFactory vf) {
      
        
          IValue iv_className = vf.string(className);
        
          IValue iv_fieldType = fieldType.createVallangInstance(vf);
        
          IValue iv_fieldName = vf.string(fieldName);
        
          
        return vf.constructor(getVallangConstructor()
                 
                 , iv_className 
                
                 , iv_fieldType 
                
                 , iv_fieldName 
                
                 ); 
      }
     
      @Override
      public String getConstructor() {
         return "fieldSignature";
      }
       
                                  
    
}