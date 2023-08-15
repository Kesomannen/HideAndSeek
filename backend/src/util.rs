use std::collections::HashMap;
use std::hash::Hash;

use rand::prelude::*;
use rand::{distributions::Standard, rngs::ThreadRng, Rng};

pub fn generate_id<K, V>(rng: &mut ThreadRng, map: &HashMap<K, V>) -> K where
    Standard: Distribution<K>,
    K: Eq + Hash
{
    loop {
        let id = rng.gen();
        if !map.contains_key(&id) {
            return id;
        }
    }
}