module type NSubPropFunct = 
 functor (N:NAxioms.NAxiomsSig') ->
 sig 
  module OrderElts : 
   sig 
    type t = N.t
   end
  
  module OrderTac : 
   sig 
    
   end
  
  val if_zero : 'a1 -> 'a1 -> N.t -> 'a1
 end
